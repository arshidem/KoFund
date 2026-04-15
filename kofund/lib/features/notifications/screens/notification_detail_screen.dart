import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/features/notifications/models/notification_model.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/notification_navigator.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:kofund/core/constants/notification_types.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/features/participants/providers/participant_provider.dart';
import 'package:kofund/features/participants/models/participant_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/programs/providers/program_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/features/contributions/providers/contribution_provider.dart';
import 'package:kofund/features/programs/utils/contribution_receipt_image.dart';

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({super.key});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool _isJoining = false;
  bool? _hasAlreadyJoined; // null = loading, false = not joined, true = joined
  bool? _isPendingUserResolved; // null = loading, false = pending, true = approved/rejected
  bool _isFetchingReceipt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init() async {
    final notification =
        ModalRoute.of(context)!.settings.arguments as AppNotification;
    final provider = context.read<NotificationProvider>();

    // Mark as read
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }

    // Check join status for program announcements
    final programId =
        notification.programId ?? notification.data['programId']?.toString();
    if (notification.type == NotificationType.announcement &&
        programId != null &&
        programId.isNotEmpty) {
      await _checkJoinStatus(programId);
    }

    // Check pending user status
    if (notification.type == NotificationType.pendingUser) {
      await _checkPendingUserStatus(notification.data);
    }
  }

  Future<void> _checkPendingUserStatus(Map<String, dynamic> data) async {
    final pendingUserId = data['pendingUserId'] ?? data['userId'];
    if (pendingUserId == null) {
      if (mounted) setState(() => _isPendingUserResolved = true);
      return;
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(pendingUserId).get();
      if (!userDoc.exists) {
        if (mounted) setState(() => _isPendingUserResolved = true);
        return;
      }
      
      final userData = userDoc.data()!;
      final isApproved = userData['isApproved'] == true;
      final currentCommunityId = userData['communityId'];
      final expectedCommunityId = data['communityId'];
      
      // If the user was already approved, or if their community ID was changed (e.g. they joined elsewhere)
      if (isApproved || currentCommunityId != expectedCommunityId) {
        if (mounted) setState(() => _isPendingUserResolved = true);
      } else {
        if (mounted) setState(() => _isPendingUserResolved = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isPendingUserResolved = true);
    }
  }

  Future<void> _checkJoinStatus(String programId) async {
    final auth = context.read<AppAuthProvider>();
    final participantProvider = context.read<ParticipantProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    try {
      final participants =
          await participantProvider.streamProgramParticipants(programId).first;
      final joined =
          participants.any((p) => p.userId == uid && p.status == 'joined');
      if (mounted) setState(() => _hasAlreadyJoined = joined);
    } catch (_) {
      if (mounted) setState(() => _hasAlreadyJoined = false);
    }
  }

  Future<void> _joinProgram(String programId) async {
    final auth = context.read<AppAuthProvider>();
    final participantProvider = context.read<ParticipantProvider>();
    final programProvider = context.read<ProgramProvider>();
    final currentUser = auth.user;
    if (currentUser == null) return;

    setState(() => _isJoining = true);
    HapticHelper.medium();

    try {
      final program =
          await programProvider.getProgramById(programId).first;
      if (program == null) throw Exception('Program not found');

      final participants =
          await participantProvider.streamProgramParticipants(programId).first;

      final isFull = program.participantType == 'fixed' &&
          participants.length >= program.maxParticipants;
      if (isFull) {
        SnackbarHelper.showError(context, 'This program is full!');
        return;
      }

      final alreadyJoined = participants
          .any((p) => p.userId == currentUser.uid && p.status == 'joined');
      if (alreadyJoined) {
        SnackbarHelper.showWarning(context, 'You already joined this program');
        setState(() => _hasAlreadyJoined = true);
        return;
      }

      final participant = ParticipantModel(
        participantId: '',
        programId: programId,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'User',
        userEmail: currentUser.email ?? '',
        communityId: program.communityId,
        joinedAt: DateTime.now(),
        status: 'joined',
        contributionPaid: program.suggestedContribution != null ? 0 : null,
        hasPaidContribution: program.suggestedContribution == null,
      );

      await participantProvider.joinProgram(participant);
      HapticHelper.success();
      if (mounted) {
        setState(() => _hasAlreadyJoined = true);
        SnackbarHelper.showSuccess(context, 'Successfully joined the program! 🎉');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed to join: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _fetchContributionAndShowReceipt(String contributionId) async {
    setState(() => _isFetchingReceipt = true);
    HapticHelper.light();

    try {
      final contributionProvider = context.read<ContributionProvider>();
      final contributionModel = await contributionProvider.getContributionById(contributionId);

      if (contributionModel == null) {
        throw Exception('Contribution record no longer exists.');
      }

      if (!mounted) return;

      // Show receipt
      await ContributionReceiptImage.generateAndShowReceipt(
        context: context,
        contribution: contributionModel,
        contributorName: contributionModel.contributorName,
        programName: contributionModel.programName ?? 'Program',
      );
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not load receipt: $e');
      }
    } finally {
      if (mounted) setState(() => _isFetchingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notification =
        ModalRoute.of(context)!.settings.arguments as AppNotification;
    final provider = context.read<NotificationProvider>();

    final programId =
        notification.programId ?? notification.data['programId']?.toString();
    final isProgramAnnouncement = notification.type == NotificationType.announcement &&
        programId != null &&
        programId.isNotEmpty;

    return GradientSheetScaffold(
      title: 'Notification',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: 22),
          onPressed: () => _confirmDelete(context, provider, notification.id),
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon sphere or Image Logo
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: notification.priorityColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Builder(
                  builder: (context) {
                    final logoUrl = notification.imageUrl ?? notification.data['communityLogo'];
                    if (logoUrl != null && logoUrl.toString().isNotEmpty) {
                      return ClipOval(
                        child: Image.network(
                          logoUrl,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Icon(
                            notification.typeIcon,
                            size: 40,
                            color: notification.priorityColor,
                          ),
                        ),
                      );
                    }
                    return Icon(
                      notification.typeIcon,
                      size: 40,
                      color: notification.priorityColor,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title & Time
            Text(
              notification.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary(context),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notification.timeAgo,
              style: TextStyle(
                color: AppColors.textPrimary(context).withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 32),

            // Body Text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.textPrimary(context).withValues(alpha: 0.05),
                ),
              ),
              child: Text(
                notification.body,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color:
                      AppColors.textPrimary(context).withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Program Announcement Join Card
            if (isProgramAnnouncement) ...[
              const SizedBox(height: 28),
              _buildProgramJoinCard(context, notification, programId),
            ],

            // Additional Details
            if (notification.data.isNotEmpty &&
                _hasViewableData(notification.data)) ...[
              const SizedBox(height: 32),
              _buildSectionHeader(context, 'Additional Details'),
              const SizedBox(height: 12),
              _buildRefinedDataCard(context, notification.data),
            ],

            const SizedBox(height: 48),

            // Specialized Action Buttons
            _buildActionButtons(context, provider, notification),
          ],
        ),
      ),
    );
  }

  // ── Program Join Card ────────────────────────────────────────────────────
  Widget _buildProgramJoinCard(
    BuildContext context,
    AppNotification notification,
    String programId,
  ) {
    final primary = AppColors.primary(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.08),
            primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flag_rounded, color: primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'New Program Available!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Join status / button
          if (_hasAlreadyJoined == null)
            Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(primary),
                ),
              ),
            )
          else if (_hasAlreadyJoined == true)
            _buildJoinedBadge(context)
          else
            _buildJoinButtons(context, programId),
        ],
      ),
    );
  }

  Widget _buildJoinedBadge(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            'You\'ve joined this program',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButtons(BuildContext context, String programId) {
    final primary = AppColors.primary(context);
    return Row(
      children: [
        // View Program button (outline)
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              HapticHelper.light();
              NotificationNavigator.handleNotificationTap(context, {
                'type': 'announcement',
                'programId': programId,
              });
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
            child: Text(
              'View',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Join button (filled)
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isJoining ? null : () => _joinProgram(programId),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
            child: _isJoining
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Join Program',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context, NotificationProvider provider, AppNotification notification) {
    // 1. Pending User Approval Actions (for Admin)
    if (notification.type == NotificationType.pendingUser) {
      if (_isPendingUserResolved == null) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 16),
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      
      if (_isPendingUserResolved == true) {
        return const SizedBox.shrink(); // Action already taken
      }
      
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticHelper.medium();
                  NotificationService().onRejectUser?.call(notification.data);
                  setState(() => _isPendingUserResolved = true);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusFull)),
                ),
                child: const Text('Reject',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  HapticHelper.heavy();
                  NotificationService().onApproveUser?.call(notification.data);
                  setState(() => _isPendingUserResolved = true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusFull)),
                ),
                child: const Text('Approve',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      );
    }

    // 2. For non-announcement types that have a programId → "View Program" button
    // 🆕 Exclude approval type as per user request (no redundant "Open Community" button)
    if (notification.type != NotificationType.announcement &&
        notification.type != NotificationType.approval && 
        _canTakeAction(notification)) {
      final programId = notification.programId ??
          notification.data['programId']?.toString();
      String buttonLabel = 'View Program →';
      if (notification.deepLink != null ||
          (programId != null && programId.isNotEmpty)) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              HapticHelper.medium();
              NotificationNavigator.handleNotificationTap(context, {
                'type': notification.type.toString(),
                'deepLink': notification.deepLink,
                'programId': programId ?? '',
                ...notification.data,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5),
            ),
          ),
        );
      }
    }

    // 🆕 3. Get Receipt Action (for Contribution Recorded notifications)
    final contributionId = notification.data['contributionId']?.toString();
    if (notification.type == NotificationType.contribution &&
        contributionId != null &&
        contributionId.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isFetchingReceipt
                ? null
                : () => _fetchContributionAndShowReceipt(contributionId),
            icon: _isFetchingReceipt
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.receipt_long_rounded, size: 20),
            label: Text(
              _isFetchingReceipt ? 'Generating...' : 'Get Receipt',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  bool _hasViewableData(Map<String, dynamic> data) {
    return data.keys.any((key) => !_isInternalKey(key));
  }

  bool _isInternalKey(String key) {
    const internalKeys = {
      'type',
      'deepLink',
      'click_action',
      'targetRole',
      'fcmToken',
      'notificationId',
      'sentFromApp',
      'appVersion',
      'timestamp',
      'senderId',
      'communityId',
      'programId',
      'senderName', // 🆕 Hide sender name if it's generic
      'title',
      'body',
      'communityLogo', // 🆕 Hide the logo URL since it's rendered as an image
      'imageUrl',
    };
    if (internalKeys.contains(key)) return true;
    
    final lowerKey = key.toLowerCase();
    // 🆕 Hide specific ID fields or those ending/containing _id
    if (lowerKey == 'id' || lowerKey.endsWith('id') || lowerKey.contains('_id') || lowerKey == 'pendinguserid') return true;
    
    return false;
  }

  bool _canTakeAction(AppNotification notification) {
    final type = notification.type.toString();
    final programId = notification.programId ??
        notification.data['programId']?.toString();
    return type.contains('contribution') ||
        type.contains('reminder') ||
        type.contains('approval') ||
        (programId != null && programId.isNotEmpty);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context).withValues(alpha: 0.6),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  String _formatFormatKey(String key) {
    String formatted = key.replaceAll(RegExp(r'[_-]'), ' ');
    formatted = formatted.replaceAllMapped(
        RegExp(r'(?<=[a-z])[A-Z]'), (m) => ' ${m.group(0)}');
    if (formatted.isEmpty) return formatted;
    List<String> words = formatted.trim().split(RegExp(r'\s+'));
    return words.map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  Widget _buildRefinedDataCard(
      BuildContext context, Map<String, dynamic> data) {
    final filteredEntries =
        data.entries.where((e) => !_isInternalKey(e.key)).toList();

    if (filteredEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppColors.border(context).withValues(alpha: 0.05)),
      ),
      child: Column(
        children: filteredEntries.map((entry) {
          final isLast = filteredEntries.last == entry;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatFormatKey(entry.key),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        entry.value.toString(),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    color: AppColors.border(context).withValues(alpha: 0.5),
                    height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, NotificationProvider provider, String id) {
    HapticHelper.heavy();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Log?'),
        content: const Text(
            'This notification record will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep',
                style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () {
              provider.deleteNotification(id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
