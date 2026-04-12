// lib/features/programs/utils/contribution_receipt_image.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/contributions/models/contribution_model.dart';
import 'package:flutter/services.dart';
import 'package:kofund/core/constants/app_colors.dart';

class ContributionReceiptImage {
  // Cache for user names (userId -> userName)
  static final Map<String, String> _userNameCache = {};

  static Future<String> _getCommunityNameFromId(String communityId) async {
    try {
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .get();
      
      if (communityDoc.exists) {
        return communityDoc.data()?['name'] ?? 
               communityDoc.data()?['communityName'] ?? 
               communityDoc.data()?['title'] ?? 
               'Community';
      }
      return 'Community';
    } catch (e) {
      return 'Community';
    }
  }

  static Future<String> _getProgramNameFromId(String programId) async {
    try {
      final programDoc = await FirebaseFirestore.instance
          .collection('programs')
          .doc(programId)
          .get();
      
      if (programDoc.exists) {
        return programDoc.data()?['title'] ?? 
               programDoc.data()?['name'] ?? 
               'Program';
      }
      return 'Program';
    } catch (e) {
      return 'Program';
    }
  }

  static Future<String> _getUserNameFromCacheOrFirestore(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userName = userDoc.data()?['name'] ?? 
                        userDoc.data()?['fullName'] ?? 
                        userDoc.data()?['username'] ?? 
                        'Unknown User';
        _userNameCache[userId] = userName;
        return userName;
      }
      return 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }

  static String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      default:
        return method;
    }
  }

  // Generate and show receipt
  static Future<void> generateAndShowReceipt({
    required BuildContext context,
    required ContributionModel contribution,
    required String contributorName,
    required String programName,
    String? communityName,
  }) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch required async data
      String? addedByName;
      if (contribution.addedByUserName != null && contribution.addedByUserName!.isNotEmpty) {
        addedByName = contribution.addedByUserName;
      } else if (contribution.addedByUserId != null && contribution.addedByUserId!.isNotEmpty) {
        addedByName = await _getUserNameFromCacheOrFirestore(contribution.addedByUserId!);
      }
      
      final communityNameFromId = await _getCommunityNameFromId(contribution.communityId);
      final formattedPaymentMethod = _formatPaymentMethod(contribution.paymentMethod);
      
      // ✅ Fetch the actual program title if not provided or to ensure accuracy
      String actualProgramName = programName;
      if (programName.contains('Program ') || programName.isEmpty) {
        actualProgramName = await _getProgramNameFromId(contribution.programId);
      }
      
      String? monthDisplayName;
      if (contribution.isMonthlyContribution && contribution.monthDisplayName.isNotEmpty) {
        monthDisplayName = contribution.monthDisplayName;
      }

      if (context.mounted) {
        // Pop loading dialog
        Navigator.of(context).pop();

        // Show the actual image receipt dialog
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => ReceiptImageDialog(
            contribution: contribution,
            contributorName: contributorName,
            programName: actualProgramName,
            communityName: communityNameFromId,
            paymentMethod: formattedPaymentMethod,
            addedBy: addedByName,
            monthDisplayName: monthDisplayName,
          ),
        );
      }
    } catch (e, st) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // remove loading indicator
      }
      debugPrint('Receipt error: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate receipt: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Receipt Image Preview Dialog
class ReceiptImageDialog extends StatefulWidget {
  final ContributionModel contribution;
  final String contributorName;
  final String programName;
  final String communityName;
  final String paymentMethod;
  final String? addedBy;
  final String? monthDisplayName;

  const ReceiptImageDialog({
    super.key,
    required this.contribution,
    required this.contributorName,
    required this.programName,
    required this.communityName,
    required this.paymentMethod,
    this.addedBy,
    this.monthDisplayName,
  });

  @override
  State<ReceiptImageDialog> createState() => _ReceiptImageDialogState();
}

class _ReceiptImageDialogState extends State<ReceiptImageDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isDownloading = false;
  bool _isSharing = false;

  Future<void> _shareReceipt() async {
    setState(() => _isSharing = true);
    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (imageBytes == null) throw 'Screenshot capture failed';

      final tempDir = await getTemporaryDirectory();
      final fileName = 'KoFund_Receipt_${widget.contribution.contributionId}.png';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'image/png')],
        text: 'Here is my contribution receipt from KoFund for ${widget.programName}.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _downloadReceipt() async {
    setState(() => _isDownloading = true);
    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (imageBytes == null) throw 'Screenshot capture failed';

      // Use the proper Downloads directory for Android
      Directory? saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = await getExternalStorageDirectory();
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final fileName = 'KoFund_Receipt_${widget.contribution.contributionId}.png';
      final filePath = '${saveDir?.path}/$fileName';
      final file = File(filePath);
      
      await file.writeAsBytes(imageBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt saved to Downloads folder!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.background(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Visual Receipt (Capturable via Screenshot)
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Screenshot(
                  controller: _screenshotController,
                  child: _ReceiptCard(
                    contribution: widget.contribution,
                    contributorName: widget.contributorName,
                    programName: widget.programName,
                    communityName: widget.communityName,
                    paymentMethod: widget.paymentMethod,
                    addedBy: widget.addedBy,
                    monthDisplayName: widget.monthDisplayName,
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDownloading || _isSharing ? null : _downloadReceipt,
                    icon: _isDownloading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.download_rounded, color: AppColors.textPrimary(context), size: 20),
                    label: Text(_isDownloading ? 'Saving...' : 'Download', 
                                style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.border(context), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading || _isSharing ? null : _shareReceipt,
                    icon: _isSharing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                    label: Text(_isSharing ? 'Sharing...' : 'Share', 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final ContributionModel contribution;
  final String contributorName;
  final String programName;
  final String communityName;
  final String paymentMethod;
  final String? addedBy;
  final String? monthDisplayName;

  const _ReceiptCard({
    required this.contribution,
    required this.contributorName,
    required this.programName,
    required this.communityName,
    required this.paymentMethod,
    this.addedBy,
    this.monthDisplayName,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy • hh:mm a');
    final amountFormat = NumberFormat('#,##0.00');
    final primaryColor = AppColors.primary(context);

    // Ensure the background is solid so the screenshot doesn't come out transparent
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(
          color: AppColors.border(context),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Text(
                  communityName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'CONTRIBUTION RECEIPT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Tick Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                Text(
                  'Amount Paid',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${amountFormat.format(contribution.amount)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                    letterSpacing: -1.0,
                  ),
                ),
              ],
            ),
          ),

          // Dashed Divider Line (Aesthetic)
          Row(
            children: List.generate(
              30,
              (index) => Expanded(
                child: Container(
                  color: index.isEven ? AppColors.border(context) : Colors.transparent,
                  height: 1.5,
                ),
              ),
            ),
          ),

          // Details Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildReceiptRow(context, 'Date', dateFormat.format(contribution.createdAt.toDate())),
                const SizedBox(height: 12),
                _buildReceiptRow(context, 'Contributor', contributorName),
                const SizedBox(height: 12),
                _buildReceiptRow(context, 'Program', programName),
                
                if (monthDisplayName != null) ...[
                  const SizedBox(height: 12),
                  _buildReceiptRow(context, 'Month', monthDisplayName!),
                ],
                
                const SizedBox(height: 12),
                _buildReceiptRow(context, 'Payment Method', paymentMethod),
                
                if (addedBy != null) ...[
                  const SizedBox(height: 12),
                  _buildReceiptRow(context, 'Recorded By', addedBy!),
                ],

                const SizedBox(height: 32),
                
                // KoFund Watermark
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Image.asset(
                        'assets/logos/KoFund.png',
                        height: 14,
                        width: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Generated by KoFund',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}
