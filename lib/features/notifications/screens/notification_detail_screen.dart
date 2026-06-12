import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:provider/provider.dart';
import 'package:kofund/features/notifications/providers/notification_provider.dart';
import 'package:kofund/features/notifications/models/notification_model.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/utils/notification_navigator.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/haptic_helper.dart';
import 'package:kofund/core/constants/notification_Types.dart';
import 'package:kofund/core/services/notification_service.dart';
import 'package:kofund/core/services/virtual_user_service.dart';
import 'package:kofund/features/participants/providers/participant_provider.dart';
import 'package:kofund/features/participants/models/participant_model.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/events/providers/event_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:intl/intl.dart';
import 'package:kofund/features/contributions/providers/contribution_provider.dart';
import 'package:kofund/features/events/utils/contribution_receipt_image.dart';

class NotificationDetailScreen extends StatefulWidget {
  final AppNotification notification;
  const NotificationDetailScreen({super.key, required this.notification});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool _isJoining = false;
  bool? _hasAlreadyJoined; // null = loading, false = not joined, true = joined
  bool? _isPendingUserResolved; // null = loading, false = pending, true = approved/rejected
  bool _isFetchingReceipt = false;
  bool? _isConversionResolved; // null = loading, false = pending, true = resolved
  bool _isProcessingConversion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init() async {
    final notification = widget.notification;
    final provider = context.read<NotificationProvider>();

    // Mark as read
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }

    // Check join status for event announcements
    final eventId =
        notification.eventId ?? notification.data['eventId']?.toString();
    if (notification.type == NotificationType.announcement &&
        eventId != null &&
        eventId.isNotEmpty) {
      await _checkJoinStatus(eventId);
    }

    // Check pending user status
    if (notification.type == NotificationType.pendingUser) {
      await _checkPendingUserStatus(notification.data);
    }

    // Check conversion request status
    if (notification.type == NotificationType.conversionRequest) {
      await _checkConversionRequestStatus(notification.data);
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

  Future<void> _checkConversionRequestStatus(Map<String, dynamic> data) async {
    final virtualUserId = data['virtualUserId'];
    if (virtualUserId == null) {
      if (mounted) setState(() => _isConversionResolved = true);
      return;
    }

    try {
      // If the virtual user no longer exists, the conversion was already done
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(virtualUserId).get();
      if (!userDoc.exists) {
        if (mounted) setState(() => _isConversionResolved = true);
        return;
      }
      // Check if the merge was previously rejected
      final userData = userDoc.data();
      if (userData != null && userData['mergeRejected'] == true) {
        if (mounted) setState(() => _isConversionResolved = true);
        return;
      }
      if (mounted) setState(() => _isConversionResolved = false);
    } catch (e) {
      if (mounted) setState(() => _isConversionResolved = true);
    }
  }

  Future<void> _handleConversionAccept(Map<String, dynamic> data) async {
    setState(() => _isProcessingConversion = true);
    HapticHelper.heavy();

    try {
      final virtualUserId = data['virtualUserId'] as String?;
      final realUserId = data['realUserId'] as String?;
      final adminId = data['adminId'] as String?;
      final virtualUserName = data['virtualUserName'] as String? ?? 'Virtual User';

      if (virtualUserId == null || realUserId == null) {
        throw Exception('Missing user IDs for conversion');
      }

      // Perform the actual merge
      final virtualUserService = VirtualUserService();
      await virtualUserService.convertVirtualUser(virtualUserId, realUserId);

      // Notify the admin that the conversion was accepted
      if (adminId != null && adminId.isNotEmpty) {
        final auth = context.read<AppAuthProvider>();
        final currentUserName = auth.user?.displayName ?? 'User';
        NotificationService().sendUserNotification(
          userId: adminId,
          title: 'Merge Accepted',
          body: '$currentUserName accepted the merge of virtual member "$virtualUserName" into their account.',
          type: NotificationType.update,
          communityId: data['communityId']?.toString(),
          senderName: currentUserName,
          data: {
            'virtualUserName': virtualUserName,
            'realUserName': currentUserName,
          },
        ).catchError((e) {
          debugPrint('⚠️ Failed to notify admin about merge acceptance: $e');
        });
      }

      if (mounted) {
        setState(() => _isConversionResolved = true);
        HapticHelper.success();
        SnackbarHelper.showSuccess(context, 'Account merged successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Merge failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessingConversion = false);
    }
  }

  Future<void> _handleConversionReject(Map<String, dynamic> data) async {
    setState(() => _isProcessingConversion = true);
    HapticHelper.medium();

    try {
      final virtualUserId = data['virtualUserId'] as String?;
      final adminId = data['adminId'] as String?;
      final virtualUserName = data['virtualUserName'] as String? ?? 'Virtual User';

      // Persist the rejection in Firestore so buttons stay hidden on reopen
      if (virtualUserId != null) {
        await FirebaseFirestore.instance.collection('users').doc(virtualUserId).update({
          'mergeRejected': true,
          'mergeRejectedAt': FieldValue.serverTimestamp(),
        });
      }

      // Notify the admin that the conversion was rejected
      if (adminId != null && adminId.isNotEmpty) {
        final auth = context.read<AppAuthProvider>();
        final currentUserName = auth.user?.displayName ?? 'User';
        await NotificationService().sendUserNotification(
          userId: adminId,
          title: 'Merge Rejected',
          body: '$currentUserName rejected the merge of virtual member "$virtualUserName" into their account.',
          type: NotificationType.update,
          communityId: data['communityId']?.toString(),
          senderName: currentUserName,
          data: {
            'virtualUserName': virtualUserName,
            'realUserName': currentUserName,
          },
        );
      }

      if (mounted) {
        setState(() => _isConversionResolved = true);
        SnackbarHelper.showSuccess(context, 'Merge request rejected');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to reject: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessingConversion = false);
    }
  }

  Future<void> _checkJoinStatus(String eventId) async {
    final auth = context.read<AppAuthProvider>();
    final participantProvider = context.read<ParticipantProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    try {
      final participants =
          await participantProvider.streamEventParticipants(eventId).first;
      final joined =
          participants.any((p) => p.userId == uid && p.status == 'joined');
      if (mounted) setState(() => _hasAlreadyJoined = joined);
    } catch (_) {
      if (mounted) setState(() => _hasAlreadyJoined = false);
    }
  }

  Future<void> _joinEvent(String eventId) async {
    final auth = context.read<AppAuthProvider>();
    final participantProvider = context.read<ParticipantProvider>();
    final eventProvider = context.read<EventProvider>();
    final currentUser = auth.user;
    if (currentUser == null) return;

    setState(() => _isJoining = true);
    HapticHelper.medium();

    try {
      final event =
          await eventProvider.getEventById(eventId).first;
      if (event == null) throw Exception('event not found');

      final participants =
          await participantProvider.streamEventParticipants(eventId).first;

      final isFull = event.participantType == 'fixed' &&
          participants.length >= event.maxParticipants;
      if (isFull) {
        SnackbarHelper.showError(context, 'This event is full!');
        return;
      }

      final alreadyJoined = participants
          .any((p) => p.userId == currentUser.uid && p.status == 'joined');
      if (alreadyJoined) {
        SnackbarHelper.showWarning(context, 'You already joined this event');
        setState(() => _hasAlreadyJoined = true);
        return;
      }

      final participant = ParticipantModel(
        participantId: '',
        eventId: eventId,
        eventName: event.title,
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'User',
        userEmail: currentUser.email,
        communityId: event.communityId,
        joinedAt: DateTime.now(),
        status: 'joined',
        contributionPaid: event.suggestedContribution != null ? 0 : null,
        hasPaidContribution: event.suggestedContribution == null,
      );

      await participantProvider.joinEvent(participant);
      HapticHelper.success();
      if (mounted) {
        setState(() => _hasAlreadyJoined = true);
        SnackbarHelper.showSuccess(context, 'Successfully joined the event!');
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Failed to join: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _fetchContributionAndShowReceipt(String contributionId, String title) async {
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
        name: title,
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
    final notification = widget.notification;
    final provider = context.read<NotificationProvider>();

    final eventId =
        notification.eventId ?? notification.data['eventId']?.toString();
    final isEventAnnouncement = notification.type == NotificationType.announcement &&
        eventId != null &&
        eventId.isNotEmpty;
    final isPendingUser = notification.type == NotificationType.pendingUser;

    String getPendingUserName() {
      final dataName = notification.data['userName'] ?? notification.data['pendingUserName'] ?? notification.data['senderName'];
      if (dataName != null && dataName.toString().trim().isNotEmpty) {
        return dataName.toString();
      }
      final title = notification.title.trim();
      final joinRegex = RegExp(r'^(.+?)\s+wants\s+to\s+join', caseSensitive: false);
      final match = joinRegex.firstMatch(title);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
      if (notification.senderName != null && notification.senderName!.trim().isNotEmpty) {
        return notification.senderName!;
      }
      return 'A member';
    }

    String getCommunityName() {
      final commName = notification.communityName ?? notification.data['communityName'];
      if (commName != null && commName.toString().trim().isNotEmpty) {
        return commName.toString();
      }
      final title = notification.title.trim();
      final joinRegex = RegExp(r'wants\s+to\s+join\s+(.+)$', caseSensitive: false);
      final match = joinRegex.firstMatch(title);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
      return 'Community';
    }

    final userName = getPendingUserName();
    final communityName = getCommunityName();

    return GradientSheetScaffold(
      title: 'Notification',
      actions: [
        IconButton(
          icon: Icon(Icons.delete_outline_rounded,
              color: AppColors.textPrimary(context), size: 22),
          onPressed: () => _confirmDelete(context, provider, notification.id),
        ),
      ],
      body: SingleChildScrollView(
        padding: AppStyles.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isPendingUser) ...[
              // Modern Join Request Design matching screenshot
              const SizedBox(height: 12),
              // Big circle icon with badge
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA6).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 48,
                          color: const Color(0xFF00BFA6),
                        ),
                      ),
                    ),
                    // Notification count badge
                    Positioned(
                      top: 4,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00BFA6),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        child: const Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    // Floating decorations
                    Positioned(
                      left: 12,
                      top: 20,
                      child: Icon(Icons.add, size: 14, color: const Color(0xFF00BFA6).withValues(alpha: 0.3)),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 24,
                      child: Icon(Icons.close, size: 10, color: const Color(0xFF00BFA6).withValues(alpha: 0.3)),
                    ),
                    Positioned(
                      left: 18,
                      bottom: 18,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00BFA6).withValues(alpha: 0.3), width: 1.5),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      top: 24,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00BFA6).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // NEW JOIN REQUEST Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'NEW JOIN REQUEST',
                  style: TextStyle(
                    color: Color(0xFF00BFA6),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title text matching screenshot layout
              Text(
                '$userName wants to join',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                communityName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF00BFA6),
                ),
              ),
              const SizedBox(height: 12),

              // Requested date/time line
              Text(
                'Requested on ${DateFormat('MMM d, yyyy').format(notification.timestamp)} at ${DateFormat('hh:mm a').format(notification.timestamp)}',
                style: TextStyle(
                  color: AppColors.textPrimary(context).withValues(alpha: 0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // Info Box (A new member has requested to join your community...)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.textPrimary(context).withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA6).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mail_outline_rounded,
                        color: Color(0xFF00BFA6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textPrimary(context).withValues(alpha: 0.8),
                          ),
                          children: [
                            const TextSpan(
                              text: 'A new member has requested to join your community.\n',
                            ),
                            TextSpan(
                              text: 'Review the request and take action.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Fully Rounded Buttons directly below the Info Box (Reject & Approve)
              _buildActionButtons(context, provider, notification),
              
              // Request Details Section
              const SizedBox(height: 28),
              // Left aligned green underlined heading "Request Details"
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Request Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.textPrimary(context).withValues(alpha: 0.03),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailsItem(
                      context,
                      Icons.people_alt_outlined,
                      'Community Name',
                      communityName,
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildDetailsItem(
                      context,
                      Icons.person_outline_rounded,
                      'Member Name',
                      userName,
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildDetailsItem(
                      context,
                      Icons.calendar_today_outlined,
                      'Requested At',
                      '${DateFormat('MMM d, yyyy').format(notification.timestamp)} • ${DateFormat('hh:mm a').format(notification.timestamp)}',
                      isBoldValue: true,
                    ),
                  ],
                ),
              ),
            ] else if (notification.type == NotificationType.conversionRequest) ...[
              // Account Merge Request Detail Screen Design
              const SizedBox(height: 12),
              // Big circle checkmark
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2196F3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.merge_type_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Floating decorations
                    Positioned(
                      left: 12,
                      top: 20,
                      child: Icon(Icons.change_history_rounded, size: 12, color: const Color(0xFF2196F3).withValues(alpha: 0.4)),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 24,
                      child: Icon(Icons.change_history_rounded, size: 14, color: const Color(0xFF2196F3).withValues(alpha: 0.4)),
                    ),
                    Positioned(
                      left: 18,
                      bottom: 18,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.3), width: 1.5),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      top: 24,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title: Account Merge Request
              Text(
                "Account Merge Request",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 10),

              // Requested date/time line
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textPrimary(context).withValues(alpha: 0.4)),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('MMM d, yyyy').format(notification.timestamp)} • ${DateFormat('h:mm a').format(notification.timestamp)}',
                    style: TextStyle(
                      color: AppColors.textPrimary(context).withValues(alpha: 0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Info card (Admin Wants to merge...)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                   
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textPrimary(context).withValues(alpha: 0.8),
                          ),
                          children: [
                            TextSpan(
                              text: 'Admin "${notification.data['adminName'] ?? 'Admin'}" wants to merge the virtual member "${notification.data['virtualUserName'] ?? 'Riyas'}" into your account. ',
                              style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary(context)),
                            ),
                            TextSpan(
                              text: 'All data from the virtual user will be transferred to you.',
                              style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary(context).withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Virtual User Details Header
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Virtual User Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Details Card (Name, Email, Requested By)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.textPrimary(context).withValues(alpha: 0.03),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDetailsItem(
                      context,
                      Icons.person_outline_rounded,
                      'Name',
                      notification.data['virtualUserName'] ?? 'Riyas',
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildDetailsItem(
                      context,
                      Icons.email_outlined,
                      'Email',
                      notification.data['virtualUserEmail'] ?? 'riyas@virtual.kofund.app',
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildDetailsItem(
                      context,
                      Icons.person_add_alt_1_outlined,
                      'Requested By',
                      notification.data['adminName'] ?? 'Arshid EM',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // What will happen? Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA6).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00BFA6).withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF00BFA6),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What will happen?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "All data from the virtual user will be permanently transferred to your account after merging.",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons (Reject / Accept & Merge)
              _buildActionButtons(context, provider, notification),
            ] else if (notification.title.contains("You're In!") || notification.type == NotificationType.approval) ...[
              // "You're In!" Join Approval Detail Screen Design
              const SizedBox(height: 12),
              // Big circle checkmark
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA6).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00BFA6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Floating decorations
                    Positioned(
                      left: 12,
                      top: 20,
                      child: Icon(Icons.change_history_rounded, size: 12, color: const Color(0xFF00BFA6).withValues(alpha: 0.4)),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 24,
                      child: Icon(Icons.change_history_rounded, size: 14, color: const Color(0xFF00BFA6).withValues(alpha: 0.4)),
                    ),
                    Positioned(
                      left: 18,
                      bottom: 18,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00BFA6).withValues(alpha: 0.3), width: 1.5),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      top: 24,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00BFA6).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title: You're In!
              Text(
                "You're In!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 10),

              // Requested date/time line
              Text(
                '${DateFormat('MMM d, yyyy').format(notification.timestamp)} • ${DateFormat('h:mm a').format(notification.timestamp)}',
                style: TextStyle(
                  color: AppColors.textPrimary(context).withValues(alpha: 0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Info card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA6).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00BFA6).withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA6).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.celebration_outlined,
                        color: Color(0xFF00BFA6),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Your request to join $communityName has been approved.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context).withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Left aligned green underlined heading "Details"
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Details Card (Approved By, Approved At, Community Name)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.textPrimary(context).withValues(alpha: 0.03),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDetailsItem(
                      context,
                      Icons.shield_outlined,
                      'Approved By',
                      notification.data['approvedBy'] ?? 'Admin',
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildDetailsItem(
                      context,
                      Icons.calendar_today_outlined,
                      'Requested At',
                      '${DateFormat('MMM d, yyyy').format(notification.timestamp)} • ${DateFormat('hh:mm a').format(notification.timestamp)}',
                      isBoldValue: true,
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildDetailsItem(
                      context,
                      Icons.people_alt_outlined,
                      'Community Name',
                      communityName,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Welcome Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA6).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00BFA6).withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    // Small cartoon-like team/welcome illustration placeholder or icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.group_add_outlined,
                        color: Color(0xFF00BFA6),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to the community!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "We're excited to have you on board.",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Premium Standard Notification Design
              const SizedBox(height: 12),
              // Beautiful circle icon sphere with low-opacity priority coloring and accents
              Center(
                child: Builder(
                  builder: (context) {
                    final iconColor = notification.type == NotificationType.contribution
                        ? AppColors.primary(context)
                        : notification.priorityColor;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Builder(
                                builder: (context) {
                                  final logoUrl = notification.imageUrl ?? notification.data['communityLogo'];
                                  if (logoUrl != null && logoUrl.toString().isNotEmpty) {
                                    return ClipOval(
                                      child: Image.network(
                                        logoUrl,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => Icon(
                                          notification.typeIcon,
                                          size: 36,
                                          color: iconColor,
                                        ),
                                      ),
                                    );
                                  }
                                  return Icon(
                                    notification.typeIcon,
                                    size: 36,
                                    color: iconColor,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        // Floating decorations matching the premium theme
                        Positioned(
                          left: 14,
                          top: 22,
                          child: Icon(Icons.star_outline_rounded, size: 12, color: iconColor.withValues(alpha: 0.4)),
                        ),
                        Positioned(
                          right: 14,
                          bottom: 24,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: iconColor.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Title & Time
              Text(
                notification.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary(context),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM d, yyyy • h:mm a').format(notification.timestamp),
                style: TextStyle(
                  color: AppColors.textPrimary(context).withValues(alpha: 0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Body Message Text Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.textPrimary(context).withValues(alpha: 0.04),
                  ),
                ),
                child: Text(
                  notification.body,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.textPrimary(context).withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // event Announcement Join Card
              if (isEventAnnouncement) ...[
                const SizedBox(height: 28),
                _buildEventJoinCard(context, notification, eventId),
              ],

              // Details Header and Data List (if present)
              if (notification.type != NotificationType.contribution && 
                  notification.data.isNotEmpty &&
                  _hasViewableData(notification.data)) ...[
                const SizedBox(height: 28),
                // Left-aligned Details section header
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildRefinedDataCard(context, notification.data),
              ],
              
              // Conversion Request Details
              if (notification.type == NotificationType.conversionRequest) ...[
                const SizedBox(height: 28),
                _buildConversionRequestCard(context, notification.data),
              ],

              // Contribution Detail (if type is contribution)
              if (notification.type == NotificationType.contribution) ...[
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Contribution Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildContributionSummary(context, notification.data),
              ],

              const SizedBox(height: 32),

              // Specialized Action Buttons (with stadium/rounded border layouts)
              _buildActionButtons(context, provider, notification),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsItem(BuildContext context, IconData icon, String label, String value, {bool isBoldValue = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00BFA6).withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFF00BFA6),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  // ── event Join Card ────────────────────────────────────────────────────
  Widget _buildEventJoinCard(
    BuildContext context,
    AppNotification notification,
    String eventId,
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
                  'New event Available!',
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
            _buildJoinButtons(context, eventId),
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
            'You\'ve joined this event',
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

  Widget _buildJoinButtons(BuildContext context, String eventId) {
    final primary = AppColors.primary(context);
    return Row(
      children: [
        // View event button (outline)
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              HapticHelper.light();
              NotificationNavigator.handleNotificationTap(context, {
                'type': 'announcement',
                'eventId': eventId,
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
            onPressed: _isJoining ? null : () => _joinEvent(eventId),
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
                        'Join event',
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

  // ── Conversion Request Card ─────────────────────────────────────────────
  Widget _buildConversionRequestCard(BuildContext context, Map<String, dynamic> data) {
    final primary = AppColors.primary(context);
    final virtualUserName = data['virtualUserName']?.toString() ?? 'Unknown';
    final virtualUserEmail = data['virtualUserEmail']?.toString() ?? '';
    final virtualUserPhone = data['virtualUserPhone']?.toString() ?? '';
    final adminName = data['adminName']?.toString() ?? 'Admin';

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
                child: Icon(Icons.merge_type_rounded, color: primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Virtual User Details',
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
          _buildSummaryRow(context, Icons.person_rounded, 'Name', virtualUserName),
          if (virtualUserEmail.isNotEmpty) ...[
            const Divider(height: 24, thickness: 0.5),
            _buildSummaryRow(context, Icons.email_rounded, 'Email', virtualUserEmail),
          ],
          if (virtualUserPhone.isNotEmpty) ...[
            const Divider(height: 24, thickness: 0.5),
            _buildSummaryRow(context, Icons.phone_rounded, 'Phone', virtualUserPhone),
          ],
          const Divider(height: 24, thickness: 0.5),
          _buildSummaryRow(context, Icons.admin_panel_settings_rounded, 'Requested By', adminName),
        ],
      ),
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
      
      return _SwipeToAcceptWidget(
        acceptLabel: 'Approve',
        rejectLabel: 'Reject',
        acceptColor: AppColors.primary(context),
        onAccepted: () {
          NotificationService().onApproveUser?.call(notification.data);
          setState(() => _isPendingUserResolved = true);
        },
        onRejected: () {
          HapticHelper.medium();
          NotificationService().onRejectUser?.call(notification.data);
          setState(() => _isPendingUserResolved = true);
        },
      );
    }

    // 1b. Conversion Request Approval Actions (for Real User)
    if (notification.type == NotificationType.conversionRequest) {
      if (_isConversionResolved == null) {
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

      if (_isConversionResolved == true) {
        return const SizedBox.shrink(); // Already processed
      }

      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _SwipeToAcceptWidget(
          acceptLabel: 'Accept & Merge',
          rejectLabel: 'Reject',
          acceptColor: AppColors.primary(context),
          isProcessing: _isProcessingConversion,
          onAccepted: () => _handleConversionAccept(notification.data),
          onRejected: () => _handleConversionReject(notification.data),
        ),
      );
    }

    // 2. For non-announcement Types that have a eventId → "View event" button
    // 🆕 Exclude approval type as per user request (no redundant "Open Community" button)
    if (notification.type != NotificationType.announcement &&
        notification.type != NotificationType.approval && 
        _canTakeAction(notification)) {
      final eventId = notification.eventId ?? notification.data['eventId']?.toString();
      String buttonLabel = 'View event →';
      if (notification.deepLink != null ||
          (eventId != null && eventId.isNotEmpty)) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              HapticHelper.medium();
              NotificationNavigator.handleNotificationTap(context, {
                'type': notification.type.toString(),
                'deepLink': notification.deepLink,
                'eventId': eventId ?? '',
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
                : () => _fetchContributionAndShowReceipt(contributionId, notification.title),
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

  // ── Contribution Summary Card ──────────────────────────────────────────
  Widget _buildContributionSummary(BuildContext context, Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _buildSummaryRow(context, Icons.account_balance_wallet_rounded, 'Event', data['eventName']?.toString() ?? 'General'),
          const Divider(height: 24, thickness: 0.5),
          _buildSummaryRow(context, Icons.calendar_month_rounded, 'Period', data['period']?.toString() ?? 'General'),
          const Divider(height: 24, thickness: 0.5),
          _buildSummaryRow(context, Icons.payments_rounded, 'Amount', data['amountRecorded']?.toString() ?? '₹0'),
          const Divider(height: 24, thickness: 0.5),
          
          if (data['targetAmount'] != null) ...[
            _buildSummaryRow(
              context, 
              Icons.analytics_rounded, 
              'Total Paid', 
              '${data['runningTotal']?.toString() ?? '₹0'} of ${data['targetAmount']?.toString() ?? '₹0'}',
              valueColor: AppColors.primary(context),
            ),
          ] else ...[
            _buildSummaryRow(
              context, 
              Icons.analytics_rounded, 
              'Running Total', 
              data['runningTotal']?.toString() ?? '₹0',
              valueColor: AppColors.primary(context),
            ),
          ],
          
          if (data['recordedBy'] != null) ...[
            const Divider(height: 24, thickness: 0.5),
            _buildSummaryRow(context, Icons.person_rounded, 'Recorded By', data['recordedBy'].toString()),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary(context).withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  bool _hasViewableData(Map<String, dynamic> data) {
    return data.keys.any((key) => !_isInternalKey(key));
  }

  bool _isInternalKey(String key) {
    final lowerKey = key.toLowerCase();
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
      'eventId',
      'senderName', // 🆕 Hide sender name if it's generic
      'title',
      'body',
      'communityLogo', // 🆕 Hide the logo URL since it's rendered as an image
      'imageUrl',
    };
    if (internalKeys.contains(key)) return true;
    
    // 🆕 Hide specific ID fields or those ending/containing _id
    if (lowerKey == 'id' || lowerKey.endsWith('id') || lowerKey.contains('_id') || lowerKey == 'pendinguserid' || lowerKey == 'contributionid') return true;
    
    // 🆕 Hide fields already in summary
    if (lowerKey == 'eventname' || lowerKey == 'period' || lowerKey == 'runningtotal' || lowerKey == 'amountrecorded' || lowerKey == 'targetamount' || lowerKey == 'recordedby') return true;

    // 🆕 Hide conversion request fields (shown in dedicated card)
    if (lowerKey == 'virtualusername' || lowerKey == 'virtualuseremail' || lowerKey == 'virtualuserphone' || lowerKey == 'realusername' || lowerKey == 'adminname') return true;

    return false;
  }

  bool _canTakeAction(AppNotification notification) {
    final type = notification.type.toString();
    final eventId = notification.eventId ?? notification.data['eventId']?.toString();
    return type.contains('contribution') ||
        type.contains('reminder') ||
        type.contains('approval') ||
        (eventId != null && eventId.isNotEmpty);
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

// ── Bidirectional Swipe Widget ───────────────────────────────────────────────
class _SwipeToAcceptWidget extends StatefulWidget {
  final String acceptLabel;
  final String rejectLabel;
  final Color acceptColor;
  final Color rejectColor;
  final VoidCallback onAccepted;
  final VoidCallback onRejected;
  final bool isProcessing;

  const _SwipeToAcceptWidget({
    this.acceptLabel = 'Approve',
    this.rejectLabel = 'Reject',
    required this.acceptColor,
    this.rejectColor = Colors.redAccent,
    required this.onAccepted,
    required this.onRejected,
    this.isProcessing = false,
  });

  @override
  State<_SwipeToAcceptWidget> createState() => _SwipeToAcceptWidgetState();
}

class _SwipeToAcceptWidgetState extends State<_SwipeToAcceptWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _springBack;
  double _dragFraction = 0.0; // -1.0 (reject) to 1.0 (accept)
  String? _result; // null = pending, 'accepted', 'rejected'
  bool _hasVibratedThreshold = false;

  @override
  void initState() {
    super.initState();
    _springBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _springBack.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double halfRange) {
    if (_result != null || widget.isProcessing || halfRange <= 0) return;
    setState(() {
      _dragFraction =
          (_dragFraction + details.delta.dx / halfRange).clamp(-1.0, 1.0);
    });

    final absFraction = _dragFraction.abs();
    if (absFraction >= 0.75) {
      if (!_hasVibratedThreshold) {
        HapticHelper.medium();
        _hasVibratedThreshold = true;
      }
    } else {
      if (_hasVibratedThreshold) {
        HapticHelper.light();
        _hasVibratedThreshold = false;
      }
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_result != null || widget.isProcessing) return;
    _hasVibratedThreshold = false;

    if (_dragFraction >= 0.75) {
      // Accept
      setState(() {
        _result = 'accepted';
        _dragFraction = 1.0;
      });
      HapticHelper.heavy();
      widget.onAccepted();
    } else if (_dragFraction <= -0.75) {
      // Reject
      setState(() {
        _result = 'rejected';
        _dragFraction = -1.0;
      });
      HapticHelper.heavy();
      widget.onRejected();
    } else {
      // Spring back to center
      final start = _dragFraction;
      late final VoidCallback listener;
      listener = () {
        if (!mounted) return;
        final t = Curves.easeOutCubic.transform(_springBack.value);
        setState(() => _dragFraction = start * (1.0 - t));
        if (_springBack.isCompleted) _springBack.removeListener(listener);
      };
      _springBack.reset();
      _springBack.addListener(listener);
      _springBack.forward();
      HapticHelper.light();
    }
  }

  @override
  Widget build(BuildContext context) {
    const trackHeight = 64.0;
    const thumbSize = 52.0;
    const edgePadding = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final minLeft = edgePadding;
        final maxLeft = trackWidth - thumbSize - edgePadding;
        final centerLeft = (minLeft + maxLeft) / 2;
        final halfRange = centerLeft - minLeft;
        final currentLeft = centerLeft + _dragFraction * halfRange;

        final absFraction = _dragFraction.abs();
        final isGoingRight = _dragFraction > 0;
        final isGoingLeft = _dragFraction < 0;

        // Track background tints based on direction
        final neutralBg = AppColors.textPrimary(context).withValues(alpha: 0.04);
        final trackBg = isGoingRight
            ? Color.lerp(neutralBg, widget.acceptColor.withValues(alpha: 0.10), absFraction)!
            : isGoingLeft
                ? Color.lerp(neutralBg, widget.rejectColor.withValues(alpha: 0.10), absFraction)!
                : neutralBg;

        final neutralBorder = AppColors.textPrimary(context).withValues(alpha: 0.08);
        final trackBorder = isGoingRight
            ? Color.lerp(neutralBorder, widget.acceptColor.withValues(alpha: 0.25), absFraction)!
            : isGoingLeft
                ? Color.lerp(neutralBorder, widget.rejectColor.withValues(alpha: 0.25), absFraction)!
                : neutralBorder;

        // Thumb color transitions from primary brand color to accept/reject color based on drag
        final neutralThumb = AppColors.primary(context);
        final thumbColor = _result == 'rejected'
            ? widget.rejectColor
            : _result == 'accepted'
                ? widget.acceptColor
                : isGoingLeft
                    ? Color.lerp(neutralThumb, widget.rejectColor, absFraction)!
                    : isGoingRight
                        ? Color.lerp(neutralThumb, widget.acceptColor, absFraction)!
                        : neutralThumb;

        return Container(
          height: trackHeight,
          decoration: BoxDecoration(
            color: trackBg,
            borderRadius: BorderRadius.circular(trackHeight / 2),
            border: Border.all(color: trackBorder),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left label "← Reject"
              if (_result == null)
                Positioned(
                  left: 22,
                  child: AnimatedOpacity(
                    opacity: isGoingRight
                        ? (1.0 - absFraction * 2.5).clamp(0.0, 0.6)
                        : (0.4 + absFraction * 0.5).clamp(0.0, 0.9),
                    duration: const Duration(milliseconds: 100),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left_rounded,
                            size: 16,
                            color: widget.rejectColor.withValues(alpha: 0.6)),
                        Text(
                          widget.rejectLabel,
                          style: TextStyle(
                            color: widget.rejectColor
                                .withValues(alpha: isGoingLeft ? 0.5 + absFraction * 0.4 : 0.45),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Right label "Approve →"
              if (_result == null)
                Positioned(
                  right: 22,
                  child: AnimatedOpacity(
                    opacity: isGoingLeft
                        ? (1.0 - absFraction * 2.5).clamp(0.0, 0.6)
                        : (0.4 + absFraction * 0.5).clamp(0.0, 0.9),
                    duration: const Duration(milliseconds: 100),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.acceptLabel,
                          style: TextStyle(
                            color: widget.acceptColor
                                .withValues(alpha: isGoingRight ? 0.5 + absFraction * 0.4 : 0.45),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 16,
                            color: widget.acceptColor.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                ),

              // Result state text (after swipe completes)
              if (_result != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isProcessing)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            _result == 'accepted'
                                ? widget.acceptColor
                                : widget.rejectColor,
                          ),
                        ),
                      )
                    else
                      Icon(
                        _result == 'accepted'
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 20,
                        color: _result == 'accepted'
                            ? widget.acceptColor
                            : widget.rejectColor,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _result == 'accepted'
                          ? (widget.isProcessing ? 'Processing...' : 'Approved!')
                          : 'Rejected',
                      style: TextStyle(
                        color: _result == 'accepted'
                            ? widget.acceptColor
                            : widget.rejectColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

              // Draggable thumb (center-start, bidirectional)
              Positioned(
                left: currentLeft,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => _onDragUpdate(d, halfRange),
                  onHorizontalDragEnd: _onDragEnd,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: thumbColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _result != null && widget.isProcessing
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Icon(
                            _result == 'accepted'
                                ? Icons.check_rounded
                                : _result == 'rejected'
                                    ? Icons.close_rounded
                                    : isGoingLeft
                                        ? Icons.arrow_back_rounded
                                        : isGoingRight
                                            ? Icons.arrow_forward_rounded
                                            : Icons.swap_horiz_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
