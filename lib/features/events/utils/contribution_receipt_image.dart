import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kofund/features/contributions/models/contribution_model.dart';
import 'package:kofund/core/constants/app_colors.dart';

import 'package:kofund/core/skeleton/receipt_skeleton.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class ContributionReceiptImage {
  static final Map<String, String> _userNnameCache = {};

  static Future<String> _getCommunityNnameFromId(String communityId) async {
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

  static Future<String> _getNameFromId(String eventId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      
      if (doc.exists) {
        return doc.data()?['title'] ?? 
               doc.data()?['name'] ?? 
               'event';
      }
      return 'event';
    } catch (e) {
      return 'event';
    }
  }

  static Future<String> _getUserNnameFromCacheOrFirestore(String userId) async {
    if (_userNnameCache.containsKey(userId)) {
      return _userNnameCache[userId]!;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userName = userDoc.data()?['displayName'] ??
                        userDoc.data()?['name'] ?? 
                        userDoc.data()?['fullName'] ?? 
                        userDoc.data()?['username'] ?? 
                        'Unknown User';
        _userNnameCache[userId] = userName;
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
    String? contributorName,
    required String name,
    String? communityName,
  }) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: ReceiptSkeleton(),
          ),
        ),
      ),
    );
    try {
      // Fetch required async data
      // Step 1: Prioritize explicit contributorName passed to method
      // Step 2: Use contributorName stored in the model
      // Step 3: Fetch from Firestore as a final fallback
      String actualContributorName = contributorName ?? contribution.contributorName;
      if (actualContributorName.isEmpty || actualContributorName == 'Unknown User') {
        actualContributorName = await _getUserNnameFromCacheOrFirestore(contribution.userId);
      }

      // Determine "Recorded By" name
      String addedByName = 'Admin';
      
      // If we have a stored name and it's NOT just the generic "Admin", use it
      if (contribution.addedByUserName != null && 
          contribution.addedByUserName!.isNotEmpty && 
          contribution.addedByUserName != 'Admin') {
        addedByName = contribution.addedByUserName!;
      } 
      // If the stored name is "Admin" (generic) but we HAVE an ID, try to get the real name
      else if (contribution.addedByUserId != null && contribution.addedByUserId!.isNotEmpty) {
        final fetchedName = await _getUserNnameFromCacheOrFirestore(contribution.addedByUserId!);
        if (fetchedName != 'Unknown User') {
          addedByName = fetchedName;
        } else if (contribution.addedByUserName != null) {
          addedByName = contribution.addedByUserName!; // Fallback to whatever was stored
        }
      }
      
      final communityNameFromId = await _getCommunityNnameFromId(contribution.communityId);
      final formattedPaymentMethod = _formatPaymentMethod(contribution.paymentMethod);
      
      // ✅ Fetch the actual event title if not provided or to ensure accuracy
      String actualName = name;
      if (name.contains('event ') || name.isEmpty) {
        actualName = await _getNameFromId(contribution.contributionId);
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
            contributorName: actualContributorName,
            name: actualName,
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
        SnackbarHelper.showError(context, 'Failed to generate receipt: ${e.toString()}');
      }
    }
  }

}

// Receipt Image Preview Dialog
class ReceiptImageDialog extends StatefulWidget {
  final ContributionModel contribution;
  final String contributorName;
  final String name;
  final String communityName;
  final String paymentMethod;
  final String? addedBy;
  final String? monthDisplayName;

  const ReceiptImageDialog({
    super.key,
    required this.contribution,
    required this.contributorName,
    required this.name,
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

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: 'image/png')],
          text: 'Here is my contribution receipt from KoFund for ${widget.name}.',
        ),
      );
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Share failed: $e');
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
        SnackbarHelper.showSuccess(context, 'Receipt saved to Downloads folder!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Download failed: $e');
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
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: Screenshot(
                    controller: _screenshotController,
                    child: _ReceiptCard(
                      contribution: widget.contribution,
                      contributorName: widget.contributorName,
                      name: widget.name,
                      communityName: widget.communityName,
                      paymentMethod: widget.paymentMethod,
                      addedBy: widget.addedBy,
                      monthDisplayName: widget.monthDisplayName,
                    ),
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
  final String name;
  final String communityName;
  final String paymentMethod;
  final String? addedBy;
  final String? monthDisplayName;

  const _ReceiptCard({
    required this.contribution,
    required this.contributorName,
    required this.name,
    required this.communityName,
    required this.paymentMethod,
    this.addedBy,
    this.monthDisplayName,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy • hh:mm a');
    final aamountFormat = NumberFormat('#,##0.00');
    const tealColor = Color(0xFF00BFA6);
    const darkTextColor = Color(0xFF0D1B2A);

    return Container(
      width: 580,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(48),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 50,
            offset: const Offset(0, 25),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(48),
        child: Stack(
          children: [
            // Decorative elements
            Positioned(
              top: -30,
              left: -30,
              child: _buildCornerDecoration(tealColor),
            ),
            Positioned(
              top: 40,
              right: 32,
              child: _buildDotsGrid(),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: _buildBottomDecoration(tealColor),
            ),            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Indicator
                  _buildSuccessCheck(tealColor),
                  const SizedBox(height: 8),

                  // Organization Name
                  Text(
                    communityName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: darkTextColor,
                      letterSpacing: 1.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  
                  // Receipt Ttitle with lines
                  _buildReceiptTtitleLine(tealColor),
                  const SizedBox(height: 12),

                  // Amount Section (Nested Card)
                  _buildAamountSection(aamountFormat, tealColor),
                  const SizedBox(height: 12),

                  // Paid By Section
                  _buildPaidBySection(contributorName, tealColor),
                  const SizedBox(height: 12),

                  // Details Section Header (Subtle)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        'TRANSACTION DETAILS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[400],
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),

                  // Details List
                  _buildDetailItem(Icons.calendar_month_rounded, 'Date', dateFormat.format(contribution.createdAt.toDate()), tealColor),
                  
                  if (monthDisplayName != null) ...[
                    _buildDetailDivider(),
                    _buildDetailItem(Icons.calendar_today_rounded, 'Month', monthDisplayName!, tealColor),
                  ],

                  _buildDetailDivider(),
                  _buildDetailItem(Icons.card_membership_rounded, 'Event', name, tealColor),
                  _buildDetailDivider(),
                  _buildDetailItem(Icons.account_balance_wallet_outlined, 'Payment Method', paymentMethod, tealColor),
                  
                  _buildDetailDivider(),
                  _buildDetailItem(Icons.assignment_ind_rounded, 'Recorded By', addedBy ?? 'Admin', tealColor),
                  
                  const SizedBox(height: 16),

                  // Footer
                  _buildFooter(tealColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSuccessCheck(Color color) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 52,
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptTtitleLine(Color color) {
    return Row(
      children: [
        Expanded(child: Divider(color: color.withValues(alpha: 0.3), thickness: 2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'CONTRIBUTION RECEIPT',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 4.0,
            ),
          ),
        ),
        Expanded(child: Divider(color: color.withValues(alpha: 0.3), thickness: 2)),
      ],
    );
  }

  Widget _buildAamountSection(NumberFormat format, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 15),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            'AMOUNT PAID',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.grey[500],
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '₹${format.format(contribution.amount)}',
              style: TextStyle(
                fontSize: 68,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -2.0,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Divider with dot
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[100], thickness: 2)),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.6), shape: BoxShape.circle),
              ),
              Expanded(child: Divider(color: Colors.grey[100], thickness: 2)),
            ],
          ),
          
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 20, color: color),
                const SizedBox(width: 10),
                Text(
                  'Contribution Recorded',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaidBySection(String name, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, color: color, size: 42),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAID BY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[500],
                    letterSpacing: 1.5,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0D1B2A),
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Thank you for your generous contribution!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Opacity(
            opacity: 0.15,
            child: Icon(Icons.volunteer_activism_outlined, size: 56, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 68, top: 4, bottom: 4),
      child: Divider(color: Colors.grey[50], thickness: 2),
    );
  }

  Widget _buildFooter(Color color) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: color.withValues(alpha: 0.15), thickness: 2)),
            const SizedBox(width: 20),
            Container(
              width: 24,
              height: 24,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: SvgPicture.asset(
                'assets/logos/KoFund.svg',
              ),
            ),
            const SizedBox(width: 12),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                children: [
                  TextSpan(text: 'Generated by ', style: TextStyle(color: Colors.grey[700])),
                  TextSpan(text: 'KoFund', style: TextStyle(color: color)),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: Divider(color: color.withValues(alpha: 0.15), thickness: 2)),
          ],
        ),
      ],
    );
  }

  Widget _buildDotsGrid() {
    return Opacity(
      opacity: 0.08,
      child: Column(
        children: List.generate(8, (r) => Row(
          children: List.generate(8, (c) => Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.all(5),
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
          )),
        )),
      ),
    );
  }

  Widget _buildCornerDecoration(Color color) {
    return Container(
      width: 220,
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(200)),
      ),
    );
  }

  Widget _buildBottomDecoration(Color color) {
    return Container(
      width: 250,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(200)),
      ),
    );
  }
}






