// lib/features/contributions/utils/contribution_receipt_pdf.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/features/contributions/models/contribution_model.dart';
import 'package:flutter/services.dart';

class ContributionReceiptPdf {
  // Cache for user names (userId -> userName)
  static final Map<String, String> _userNameCache = {};
// Add this method to get community name from Firestore
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
    debugPrint('Error fetching community name: $e');
    return 'Community';
  }
}
  // Helper method to get user name from cache or Firestore
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
      debugPrint('Error fetching user name: $e');
      return 'Unknown User';
    }
  }

  // Generate receipt from ContributionModel
  static Future<Uint8List> generateReceiptFromContribution({
    required ContributionModel contribution,
    required String contributorName,
    required String programName,
    String? communityName,
  }) async {
    // Format payment method
    final formattedPaymentMethod = _formatPaymentMethod(contribution.paymentMethod);
    
    // Get month display name if available
    String? monthDisplayName;
    if (contribution.isMonthlyContribution && contribution.monthDisplayName.isNotEmpty) {
      monthDisplayName = contribution.monthDisplayName;
    }

    // Get added by name if available
    String? addedByName;
    if (contribution.addedByUserName != null && contribution.addedByUserName!.isNotEmpty) {
      addedByName = contribution.addedByUserName;
    } else if (contribution.addedByUserId != null && contribution.addedByUserId!.isNotEmpty) {
      addedByName = await _getUserNameFromCacheOrFirestore(contribution.addedByUserId!);
    }
  final communityNameFromId = await _getCommunityNameFromId(contribution.communityId);


    return generateReceiptFromModel(
      contributorName: contributorName,
      programName: programName,
      amount: contribution.amount,
      date: contribution.createdAt.toDate(),
      paymentMethod: formattedPaymentMethod,
      transactionId: contribution.contributionId,
      addedBy: addedByName,
      note: '',
      monthDisplayName: monthDisplayName,
      communityName: communityNameFromId,
    );
  }

// Main PDF Generation Logic - Using built-in fonts only
static Future<Uint8List> generateReceiptFromModel({
  required String contributorName,
  required String programName,
  required double amount,
  required DateTime date,
  required String paymentMethod,
  required String transactionId,
  String? addedBy,
  String? note,
  String? monthDisplayName,
  String? communityName,
}) async {
  final pdf = pw.Document();
  
  // Format date and amount
  final dateFormat = DateFormat('dd MMM yyyy - hh:mm a');
  final amountFormat = NumberFormat('#,##0.00');
  final formattedDate = dateFormat.format(date);
  final formattedAmount = 'Rs. ${amountFormat.format(amount)}';
  
  // Define colors
  final customColor = PdfColor.fromHex('#00BFA6');
  final watermarkColor = PdfColor.fromHex('#B3E0DC');
  final logoBytes = await rootBundle.load('assets/logos/KoFund.png');
final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
final checkBytes = await rootBundle.load('assets/icons/checked.png');
final checkIcon = pw.MemoryImage(checkBytes.buffer.asUint8List());

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(60 * PdfPageFormat.mm, 85 * PdfPageFormat.mm),
      margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
build: (pw.Context context) {
  return pw.Center(
    child: pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(
          color: PdfColors.grey300,
          width: 0.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // ───── COMMUNITY + TITLE ─────
          pw.Text(
            communityName?.isNotEmpty == true ? communityName! : 'KoFund',
            style: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Contribution Receipt',
            style: pw.TextStyle(
              fontSize: 4.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),

          pw.SizedBox(height: 8),

          // ───── TICK ICON ─────
pw.Container(
  width: 28,
  height: 28,
  decoration: pw.BoxDecoration(
    shape: pw.BoxShape.circle,
    color: customColor,
  ),
  padding: const pw.EdgeInsets.all(5),
  child: pw.Image(
    checkIcon,
    fit: pw.BoxFit.contain,
  ),
),


          pw.SizedBox(height: 8),

          // ───── AMOUNT ─────
          pw.Text(
            'Amount Paid',
            style: pw.TextStyle(
              fontSize: 4.5,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            formattedAmount,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: customColor,
            ),
          ),

          pw.Divider(thickness: 0.2),

          // ───── DETAILS (iOS LIST STYLE) ─────
          _iosDetail('Date', formattedDate),
          _iosDetail('Contributor', contributorName),
          _iosDetail('Program', programName),
          _iosDetail('Payment Method', paymentMethod),
          if (addedBy != null && addedBy.isNotEmpty)
            _iosDetail('Added By', addedBy),

          pw.Divider(thickness: 0.2),

          // ───── THANK YOU ─────
          pw.SizedBox(height: 4),
          pw.Text(
            'Thank you for your contribution!',
            style: pw.TextStyle(
              fontSize: 4.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),

          pw.SizedBox(height: 10),

          // ───── GENERATED BY ─────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 6,
                height: 6,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: customColor,
                ),
                child: pw.ClipOval(
                  child: pw.Image(logoImage),
                ),
              ),
              pw.SizedBox(width: 2),
              pw.Text(
                'Generated by KoFund',
                style: pw.TextStyle(
                  fontSize: 3.8,
                  color: PdfColors.grey600,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
},


    ),
  );
  return await pdf.save();
}

  // Helper methods - REMOVED font parameter
  static pw.Widget _buildInfoRow(String label, String value, {bool isSmall = false}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isSmall ? 3 : 4,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isSmall ? 3 : 4,
              color: PdfColors.grey800,
            ),
          ),
        ),
      ],
    );
  }
static pw.Widget _iosDetail(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 4.3,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 4.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ),
      ],
    ),
  );
}


  static pw.Widget _buildDetailRow(String label, String value, {bool isSmall = false}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isSmall ? 3 : 4,
            fontWeight: pw.FontWeight.normal,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isSmall ? 3 : 4,
              color: PdfColors.grey900,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
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

  // Utility method to generate and show receipt in one call
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
      final pdfBytes = await generateReceiptFromContribution(
        contribution: contribution,
        contributorName: contributorName,
        programName: programName,
        communityName: communityName,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        await showReceiptPreview(
          context: context,
          pdfBytes: pdfBytes,
          contributionId: contribution.contributionId,
        );
      }
    } catch (e, st) {
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
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

  // Show receipt preview
  static Future<void> showReceiptPreview({
    required BuildContext context,
    required Uint8List pdfBytes,
    required String contributionId,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ReceiptPreviewDialog(
        pdfBytes: pdfBytes,
        contributionId: contributionId,
      ),
    );
  }

  // Download PDF
  static Future<void> downloadPdf({
    required BuildContext context,
    required Uint8List pdfBytes,
    required String contributionId,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Saving Receipt...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final directory = await getExternalStorageDirectory();
      final downloadsPath = Directory('/storage/emulated/0/Download');
      
      final saveDir = await downloadsPath.exists() ? downloadsPath : directory;
      final fileName = 'KoFund_Receipt_$contributionId.pdf';
      final filePath = '${saveDir?.path}/$fileName';
      final file = File(filePath);
      
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt saved to Downloads folder!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      debugPrint('Receipt saved to: $filePath');
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Share PDF
  static Future<void> sharePdf({
    required BuildContext context,
    required Uint8List pdfBytes,
    required String contributionId,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Preparing to share...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'KoFund_Receipt_$contributionId.pdf';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        subject: 'KoFund Contribution Receipt',
        text: 'Here is my contribution receipt from KoFund',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Receipt Preview Dialog
class ReceiptPreviewDialog extends StatefulWidget {
  final Uint8List pdfBytes;
  final String contributionId;

  const ReceiptPreviewDialog({
    super.key,
    required this.pdfBytes,
    required this.contributionId,
  });

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  bool _isDownloading = false;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.69,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Contribution Receipt',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // PDF Preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: PdfPreview(
                    build: (format) => widget.pdfBytes,
                    allowPrinting: false, // Disable printing
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    pdfFileName: 'KoFund_Receipt_${widget.contributionId}',
                  ),
                ),
              ),
            ),

            // Action Buttons - ONLY DOWNLOAD AND SHARE
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _isDownloading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_isDownloading ? 'Downloading...' : 'Download'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isDownloading || _isSharing
                          ? null
                          : () async {
                              setState(() => _isDownloading = true);
                              try {
                                await ContributionReceiptPdf.downloadPdf(
                                  context: context,
                                  pdfBytes: widget.pdfBytes,
                                  contributionId: widget.contributionId,
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isDownloading = false);
                                }
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isSharing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.share_rounded),
                      label: Text(_isSharing ? 'Sharing...' : 'Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isDownloading || _isSharing
                          ? null
                          : () async {
                              setState(() => _isSharing = true);
                              try {
                                await ContributionReceiptPdf.sharePdf(
                                  context: context,
                                  pdfBytes: widget.pdfBytes,
                                  contributionId: widget.contributionId,
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isSharing = false);
                                }
                              }
                            },
                    ),
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
