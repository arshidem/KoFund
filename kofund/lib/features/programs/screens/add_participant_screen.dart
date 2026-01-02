// 📁 lib/features/programs/screens/add_participant_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

import '../../../../core/constants/app_colors.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/participants/models/participant_model.dart';
import '../../../features/participants/providers/participant_provider.dart';
import '../../programs/models/program_model.dart';
import '../../../features/members/providers/member_provider.dart';

class AddParticipantScreen extends StatefulWidget {
  final ProgramModel program;

  const AddParticipantScreen({super.key, required this.program});

  @override
  State<AddParticipantScreen> createState() => _AddParticipantScreenState();
}

class _AddParticipantScreenState extends State<AddParticipantScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<UserModel> _allCommunityUsers = [];
  List<ParticipantModel> _currentParticipants = [];
  List<String> _addingParticipants = [];
  bool _isLoading = true;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    developer.log('🔄 AddParticipantScreen: Loading data for program ${widget.program.programId}');
    
    try {
      // Load all community members using MemberProvider
      final memberProvider = context.read<MemberProvider>();
      
      // Reset and load first page
      await memberProvider.loadMembers(filterType: 'all', reset: true);
      
      // Get loaded members
      final allMembers = memberProvider.members;
      developer.log('📥 AddParticipantScreen: Loaded ${allMembers.length} community members');
      
      // Load current participants
      final participantProvider = context.read<ParticipantProvider>();
      await participantProvider.loadProgramParticipants(widget.program.programId);
      final participants = participantProvider.programParticipants;
      developer.log('📥 AddParticipantScreen: Loaded ${participants.length} current participants');
      
      if (mounted) {
        setState(() {
          _allCommunityUsers = allMembers;
          _currentParticipants = participants;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      developer.log('❌ AddParticipantScreen Error: $e', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: AppColors.error(context),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreMembers() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    developer.log('🔄 AddParticipantScreen: Loading more members');
    
    setState(() => _isLoadingMore = true);
    
    try {
      final memberProvider = context.read<MemberProvider>();
      await memberProvider.loadMoreMembers(filterType: 'all');
      
      if (mounted) {
        setState(() {
          _allCommunityUsers = memberProvider.members;
          _hasMoreData = memberProvider.hasMoreData;
          _isLoadingMore = false;
        });
      }
      
      developer.log('✅ AddParticipantScreen: Loaded ${_allCommunityUsers.length} total members, hasMore: $_hasMoreData');
    } catch (e, stackTrace) {
      developer.log('❌ AddParticipantScreen Error loading more: $e', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more members: $e'),
            backgroundColor: AppColors.error(context),
          ),
        );
      }
    }
  }

  List<UserModel> get _nonParticipants {
    final currentParticipantIds = _currentParticipants.map((p) => p.userId).toSet();
    
    return _allCommunityUsers.where((user) {
      // Filter out users who are already participants
      return !currentParticipantIds.contains(user.uid);
    }).toList();
  }

  List<UserModel> get _filteredNonParticipants {
    if (_searchQuery.isEmpty) return _nonParticipants;
    
    return _nonParticipants.where((user) {
      final name = user.displayName?.toLowerCase() ?? '';
      final email = user.email?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || email.contains(query);
    }).toList();
  }

// In _addParticipant method, use this corrected version:

Future<void> _addParticipant(String userId, String userName, String userEmail) async {
  if (_addingParticipants.contains(userId)) return;
  
  developer.log('➕ AddParticipantScreen: Adding participant $userName ($userId)');
  
  setState(() {
    _addingParticipants.add(userId);
  });
  
  try {
    final participantProvider = context.read<ParticipantProvider>();
    
    // Check if already a participant
    final isAlreadyParticipant = _currentParticipants.any((p) => p.userId == userId);
    if (isAlreadyParticipant) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName is already a participant'),
          backgroundColor: AppColors.warning(context),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Create participant - CORRECT PARAMETERS
    final participant = ParticipantModel(
      participantId: '${DateTime.now().millisecondsSinceEpoch}_$userId',
      programId: widget.program.programId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      communityId: widget.program.communityId,
      contributionPaid: 0,
      hasPaidContribution: false,
      status: 'joined',
      joinedAt: DateTime.now(), // Use DateTime, not Timestamp
    );
    
    // Add participant using the new addParticipant method
    await participantProvider.addParticipant(participant);
    
    // Update local state
    if (mounted) {
      setState(() {
        // Add to current participants list
        _currentParticipants.add(participant);
        _addingParticipants.remove(userId);
      });
    }
    
    developer.log('✅ AddParticipantScreen: Added $userName to program');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $userName to program'),
        backgroundColor: AppColors.success(context),
        duration: const Duration(seconds: 2),
      ),
    );
    
  } catch (e, stackTrace) {
    developer.log('❌ AddParticipantScreen Error adding participant: $e', error: e, stackTrace: stackTrace);
    
    if (mounted) {
      setState(() {
        _addingParticipants.remove(userId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add participant: $e'),
          backgroundColor: AppColors.error(context),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

  Future<void> _removeParticipant(String userId) async {
    try {
      final participantProvider = context.read<ParticipantProvider>();
      
      // Find participant
      final participant = _currentParticipants.firstWhere(
        (p) => p.userId == userId,
      );
      
      developer.log('➖ AddParticipantScreen: Removing participant ${participant.userName}');
      
      // Remove participant
      await participantProvider.leaveProgram(widget.program.programId, userId);
      
      // Update local state
      if (mounted) {
        setState(() {
          _currentParticipants.removeWhere((p) => p.userId == userId);
        });
      }
      
      developer.log('✅ AddParticipantScreen: Removed ${participant.userName} from program');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${participant.userName} from program'),
          backgroundColor: AppColors.success(context),
          duration: const Duration(seconds: 2),
        ),
      );
      
    } catch (e, stackTrace) {
      developer.log('❌ AddParticipantScreen Error removing participant: $e', error: e, stackTrace: stackTrace);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove participant: $e'),
            backgroundColor: AppColors.error(context),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search members...',
          hintStyle: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.primary(context),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppColors.textSecondary(context),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary(context), width: 2),
          ),
          filled: true,
          fillColor: AppColors.surface(context),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontSize: 14,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildParticipantCard(ParticipantModel participant) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border(context),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary(context).withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              participant.userName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppColors.primary(context),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          participant.userName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          participant.userEmail,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.remove_circle,
            color: AppColors.error(context),
            size: 24,
          ),
          onPressed: () => _removeParticipant(participant.userId),
          tooltip: 'Remove from program',
        ),
      ),
    );
  }

  Widget _buildMemberCard(UserModel member) {
    final isAdding = _addingParticipants.contains(member.uid);
    final displayName = member.displayName ?? 'Unknown User';
    final email = member.email ?? 'No email';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border(context),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary(context).withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              displayName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppColors.primary(context),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          displayName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (member.isVirtualUser)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Virtual User',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (member.isAdmin)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    color: AppColors.primary(context),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: isAdding
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary(context),
                ),
              )
            : IconButton(
                icon: Icon(
                  Icons.add_circle,
                  color: AppColors.success(context),
                  size: 24,
                ),
                onPressed: () => _addParticipant(
                  member.uid,
                  displayName,
                  email,
                ),
                tooltip: 'Add to program',
              ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (!_isLoadingMore) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary(context),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary(context),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading members...',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 60,
            color: AppColors.textTertiary(context),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Participants'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                _buildSearchBar(),
                
                // Current Participants Section
                if (_currentParticipants.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Current Participants',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary(context).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _currentParticipants.length.toString(),
                            style: TextStyle(
                              color: AppColors.primary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: _currentParticipants.length,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: _currentParticipants.length,
                      itemBuilder: (context, index) {
                        return _buildParticipantCard(_currentParticipants[index]);
                      },
                    ),
                  ),
                ],
                
                // Available Members Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Available Members',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _filteredNonParticipants.isEmpty
                              ? AppColors.textTertiary(context).withOpacity(0.1)
                              : AppColors.success(context).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _filteredNonParticipants.length.toString(),
                          style: TextStyle(
                            color: _filteredNonParticipants.isEmpty
                                ? AppColors.textTertiary(context)
                                : AppColors.success(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Members List with pagination
                Expanded(
                  flex: 3,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (scrollNotification is ScrollEndNotification &&
                          scrollNotification.metrics.extentAfter == 0 &&
                          _hasMoreData &&
                          !_isLoadingMore) {
                        _loadMoreMembers();
                        return true;
                      }
                      return false;
                    },
                    child: _filteredNonParticipants.isEmpty
                        ? _buildEmptyState(
                            _searchQuery.isEmpty
                                ? 'All community members are already participants'
                                : 'No matching members found',
                            _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            itemCount: _filteredNonParticipants.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _filteredNonParticipants.length) {
                                return _buildLoadingIndicator();
                              }
                              return _buildMemberCard(_filteredNonParticipants[index]);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}