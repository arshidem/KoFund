// 📁 lib/features/events/screens/add_participant_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'package:kofund/core/constants/app_dimensions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/participants/models/participant_model.dart';
import '../../../features/participants/providers/participant_provider.dart';
import '../../events/models/event_model.dart';
import '../../../features/members/providers/member_provider.dart';
import 'package:kofund/core/skeleton/add_participants_skeleton.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class AddParticipantScreen extends StatefulWidget {
  final EventModel event;

  const AddParticipantScreen({super.key, required this.event});

  @override
  State<AddParticipantScreen> createState() => _AddParticipantScreenState();
}

class _AddParticipantScreenState extends State<AddParticipantScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<UserModel> _allCommunityUsers = [];
  List<ParticipantModel> _currentParticipants = [];
  final List<String> _addingParticipants = [];
  bool _isLoading = true;

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
    developer.log('🔄 AddParticipantScreen: Loading data for event ${widget.event.eventId}');
    
    try {
      // Load all community members using MemberProvider
      final memberProvider = context.read<MemberProvider>();
      
      // Reset and load first page
      await memberProvider.loadMembers(filterTeventType: 'all', reset: true);
      
      // Get loaded members
      final allMembers = memberProvider.members;
      developer.log('📥 AddParticipantScreen: Loaded ${allMembers.length} community members');
      
      // Load current participants
      final participantProvider = context.read<ParticipantProvider>();
      await participantProvider.loadEventParticipants(widget.event.eventId);
      final participants = participantProvider.participants;
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
        SnackbarHelper.showError(context, 'Failed to load data: $e');
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
      final email = user.email.toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || email.contains(query);
    }).toList();
  }

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
        SnackbarHelper.showInfo(context, '$userName is already a participant');
        return;
      }
      
      // Create participant
      final participant = ParticipantModel(
        participantId: '${DateTime.now().millisecondsSinceEpoch}_$userId',
        eventId: widget.event.eventId,
        eventName: widget.event.title,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        communityId: widget.event.communityId,
        contributionPaid: 0,
        hasPaidContribution: false,
        status: 'joined',
        joinedAt: DateTime.now(),
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
      
      developer.log('✅ AddParticipantScreen: Added $userName to event');
      
      SnackbarHelper.showSuccess(context, 'Added $userName to event');
      
    } catch (e, stackTrace) {
      developer.log('❌ AddParticipantScreen Error adding participant: $e', error: e, stackTrace: stackTrace);
      
      if (mounted) {
        setState(() {
          _addingParticipants.remove(userId);
        });
        
        SnackbarHelper.showError(context, 'Failed to add participant: $e');
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
      await participantProvider.leaveEvent(widget.event.eventId, userId);
      
      // Update local state
      if (mounted) {
        setState(() {
          _currentParticipants.removeWhere((p) => p.userId == userId);
        });
      }
      
      developer.log('✅ AddParticipantScreen: Removed ${participant.userName} from event');
      
      SnackbarHelper.showSuccess(context, 'Removed ${participant.userName} from event');
      
    } catch (e, stackTrace) {
      developer.log('❌ AddParticipantScreen Error removing participant: $e', error: e, stackTrace: stackTrace);
      
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to remove participant: $e');
      }
    }
  }

  Widget _buildModernSearchBar() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color searchBg = isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.surface(context).withValues(alpha: 0.8);
    final Color searchBorder = isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context);
    final Color textColor = isDark ? Colors.white : AppColors.textPrimary(context);
    final Color iconColorVal = isDark ? Colors.white70 : Colors.black;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
                letterSpacing: 0.3,
              ),
              cursorColor: isDark ? Colors.white : AppColors.primary(context),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Search members...',
                hintStyle: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(Icons.search, color: iconColorVal, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 18, color: iconColorVal),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: searchBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: searchBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: searchBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  borderSide: BorderSide(color: searchBorder),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantCardFull(ParticipantModel participant) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary(context).withValues(alpha: 0.1),
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
        trailing: SizedBox(
          width: 80,
          child: ElevatedButton.icon(
            onPressed: () => _removeParticipant(participant.userId),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error(context).withValues(alpha: 0.1),
              foregroundColor: AppColors.error(context),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            label: const Text(
              'Remove',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantChip(ParticipantModel participant) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary(context).withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.primary(context).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    participant.userName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: GestureDetector(
                  onTap: () => _removeParticipant(participant.userId),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.error(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background(context), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            participant.userName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(UserModel member) {
    final isAdding = _addingParticipants.contains(member.uid);
    final displayName = member.displayName ?? 'Unknown User';
    final email = member.email ?? 'No email';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary(context).withValues(alpha: 0.1),
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
                  color: Colors.purple.withValues(alpha: 0.1),
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
                  color: AppColors.primary(context).withValues(alpha: 0.1),
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
                width: 80,
                child: ElevatedButton.icon(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success(context).withValues(alpha: 0.1),
                    foregroundColor: AppColors.success(context),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.success(context)),
                    ),
                  ),
                  label: const Text(
                    'Adding',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            : SizedBox(
                width: 80,
                child: ElevatedButton.icon(
                  onPressed: () => _addParticipant(
                    member.uid,
                    displayName,
                    email,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success(context).withValues(alpha: 0.1),
                    foregroundColor: AppColors.success(context),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _showCurrentParticipantsSheet() {
    // Local variable for the search query in the bottom sheet must be outside builder
    String localSearchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final bool isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.background(context),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppColors.border(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            'Current Participants',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary(context).withValues(alpha: 0.1),
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
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                            color: AppColors.textSecondary(context),
                          ),
                        ],
                      ),
                    ),
                    // Local Search Bar for Bottom Sheet
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: (value) {
                            setModalState(() {
                              localSearchQuery = value.toLowerCase();
                            });
                          },
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : AppColors.textPrimary(context),
                            letterSpacing: 0.3,
                          ),
                          cursorColor: isDark ? Colors.white : AppColors.primary(context),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            hintText: 'Search added members...',
                            hintStyle: TextStyle(
                              color: (isDark ? Colors.white : AppColors.textPrimary(context)).withValues(alpha: 0.6),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Icon(
                              Icons.search, 
                              color: isDark ? Colors.white70 : Colors.black, 
                              size: 20,
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.surface(context).withValues(alpha: 0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.border(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Filter participants locally
                          final filteredParticipants = _currentParticipants.where((p) {
                            final nameMatch = p.userName.toLowerCase().contains(localSearchQuery);
                            final emailMatch = p.userEmail.toLowerCase().contains(localSearchQuery);
                            return nameMatch || emailMatch;
                          }).toList();

                          if (_currentParticipants.isEmpty) {
                            return _buildEmptyState(
                              'No participants added yet',
                              Icons.group_add_outlined,
                            );
                          } else if (filteredParticipants.isEmpty && localSearchQuery.isNotEmpty) {
                            return _buildEmptyState(
                              'No matching participants found',
                              Icons.search_off,
                            );
                          }

                          return ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: filteredParticipants.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              return _buildParticipantCardFull(filteredParticipants[index]);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox.shrink();
  }

  Widget _buildLoadingState() {
    return AddParticipantSkeleton(
      isDarkMode: Theme.of(context).brightness == Brightness.dark,
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40,
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
    return GradientSheetScaffold(
      title: 'Add Participants',
      belowHeader: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _buildModernSearchBar(),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Stack(
              children: [
                Column(
                  children: [
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
                                  ? AppColors.textTertiary(context).withValues(alpha: 0.1)
                                  : AppColors.success(context).withValues(alpha: 0.1),
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
                    Expanded(
                      child: _filteredNonParticipants.isEmpty
                          ? _buildEmptyState(
                              _searchQuery.isEmpty
                                  ? 'All community members are already participants'
                                  : 'No matching members found',
                              _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 100), // padding for bottom bar
                              itemCount: _filteredNonParticipants.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                return _buildMemberCard(_filteredNonParticipants[index]);
                              },
                            ),
                    ),
                  ],
                ),
                
                // Floating Bottom Bar for Current Participants
                if (_currentParticipants.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: GestureDetector(
                      onTap: _showCurrentParticipantsSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primary(context),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary(context).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.group, color: Colors.white, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  '${_currentParticipants.length} Participants Added',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'View',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 13,
                              ),
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
}






