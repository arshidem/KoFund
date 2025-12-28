// lib/features/contributions/utils/contribution_receipt_pdf.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContributionReceiptPdf {
  // Generate premium receipt PDF
static Future<Uint8List> _generateReceiptPdf({
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
  
  // Format date and amount - REPLACE • with - and ₹ with Rs.
  final dateFormat = DateFormat('dd MMM yyyy - hh:mm a'); // Changed • to -
  final amountFormat = NumberFormat('#,##0.00');
  final formattedDate = dateFormat.format(date);
  final formattedAmount = 'Rs. ${amountFormat.format(amount)}'; // Changed ₹ to Rs.
  
  // Define the custom color (00BFA6)
  final customColor = PdfColor.fromHex('#00BFA6');
  
  // Create watermark text style with font size 30
  final watermarkTextStyle = pw.TextStyle(
    fontSize: 30, // Set to 30 as requested
    color: PdfColor.fromHex('#00BFA6').withOpacity(0.15), // Custom color with low opacity
    fontWeight: pw.FontWeight.bold,
  );

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, 210 * PdfPageFormat.mm),
      margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      build: (pw.Context context) {
        return pw.Stack(
          children: [
            // Background Watermarks - create a dense pattern with font size 30
            for (double y = -30; y < 250 * PdfPageFormat.mm; y += 60) // Reduced spacing for smaller font
              for (double x = -15; x < 70 * PdfPageFormat.mm; x += 70) // Reduced spacing for smaller font
                pw.Positioned(
                  left: x,
                  top: y,
                  child: pw.Transform.rotate(
                    angle: -0.4,
                    child: pw.Text(
                      'KoFund',
                      style: watermarkTextStyle,
                    ),
                  ),
                ),
            
            // Another layer with different angle
            for (double y = 30; y < 250 * PdfPageFormat.mm; y += 60) // Adjusted spacing
              for (double x = 45; x < 70 * PdfPageFormat.mm; x += 70) // Adjusted spacing
                pw.Positioned(
                  left: x,
                  top: y,
                  child: pw.Transform.rotate(
                    angle: 0.4,
                    child: pw.Text(
                      'KoFund',
                      style: watermarkTextStyle,
                    ),
                  ),
                ),
            
            // Main Content
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                // Header with Logo
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'KoFund',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: customColor,
                        ),
                      ),
                      pw.Text(
                        'Contribution Receipt',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Divider(thickness: 2, color: customColor),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),
                
                // Receipt Info
                _buildInfoRow('Receipt No:', transactionId),
                pw.SizedBox(height: 4),
                _buildInfoRow('Date:', formattedDate),
                
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 12),
                
                // Amount Section
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Amount Paid',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        formattedAmount,
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                          color: customColor,
                        ),
                      ),
                      if (monthDisplayName != null && monthDisplayName.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 8),
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#E0F7F5'),
                              borderRadius: pw.BorderRadius.circular(12),
                            ),
                            child: pw.Text(
                              monthDisplayName,
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: customColor,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 12),
                
                // Contribution Details
                pw.Text(
                  'Contribution Details',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: customColor,
                  ),
                ),
                pw.SizedBox(height: 12),
                
                _buildDetailRow('Contributor:', contributorName),
                pw.SizedBox(height: 6),
                _buildDetailRow('Program:', programName),
                pw.SizedBox(height: 6),
                _buildDetailRow('Payment Method:', paymentMethod),
                
                if (addedBy != null && addedBy.isNotEmpty)
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 6),
                      _buildDetailRow('Added By:', addedBy),
                    ],
                  ),
                
                if (communityName != null && communityName.isNotEmpty)
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 6),
                      _buildDetailRow('Community:', communityName),
                    ],
                  ),
                
                if (note != null && note.isNotEmpty)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 12),
                      pw.Text(
                        'Note:',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey50,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          note,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                    ],
                  ),
                
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 12),
                
                // Footer
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Thank you for your contribution!',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'This is a computer generated receipt',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey500,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'No signature required',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 16),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Generated: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
  return await pdf.save();

}


  // Helper method for info rows
  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey800,
            ),
          ),
        ),
      ],
    );
  }

  // Helper method for detail rows
  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.normal,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey900,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // Fetch contribution data and show receipt
  static Future<void> generateReceipt(
    BuildContext context,
    String contributionId,
  ) async {
    // Show loading
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
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
                  'Generating Receipt...',
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
      // Fetch contribution data from Firestore
      final contributionDoc = await FirebaseFirestore.instance
          .collection('contributions')
          .doc(contributionId)
          .get();

      if (!contributionDoc.exists) {
        throw Exception('Contribution not found');
      }

      final contributionData = contributionDoc.data() as Map<String, dynamic>;
      
      // Fetch user name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(contributionData['userId'])
          .get();
      
      final userData = userDoc.data() as Map<String, dynamic>?;
      final contributorName = userData?['name'] ?? 'Unknown User';

      // Fetch program name
      String programName = 'Unknown Program';
      if (contributionData['programId'] != null) {
        final programDoc = await FirebaseFirestore.instance
            .collection('programs')
            .doc(contributionData['programId'])
            .get();
        
        if (programDoc.exists) {
          final programData = programDoc.data() as Map<String, dynamic>;
          programName = programData['name'] ?? 'Unknown Program';
        }
      }

      // Fetch added by user name
      String? addedByName;
      if (contributionData['addedByUserId'] != null) {
        final addedByDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(contributionData['addedByUserId'])
            .get();
        
        if (addedByDoc.exists) {
          final addedByData = addedByDoc.data() as Map<String, dynamic>;
          addedByName = addedByData['name'];
        }
      }

      // Format payment method
      String paymentMethod = _formatPaymentMethod(contributionData['paymentMethod'] ?? 'Unknown');
      
      // Generate PDF
      final pdfBytes = await _generateReceiptPdf(
        contributorName: contributorName,
        programName: programName,
        amount: (contributionData['amount'] as num).toDouble(),
        date: (contributionData['createdAt'] as Timestamp).toDate(),
        paymentMethod: paymentMethod,
        transactionId: contributionId.replaceFirst('contrib_', ''),
        addedBy: addedByName,
        note: contributionData['note'],
        monthDisplayName: contributionData['monthDisplayName'],
      );

      // Close loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show receipt preview
      await _showReceiptPreview(context, pdfBytes, contributionId);

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show receipt preview
  static Future<void> _showReceiptPreview(
    BuildContext context,
    Uint8List pdfBytes,
    String contributionId,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ReceiptPreviewDialog(
        pdfBytes: pdfBytes,
        contributionId: contributionId,
      ),
    );
  }

  // Format payment method
  static String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI Payment';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'card':
        return 'Credit/Debit Card';
      default:
        return method;
    }
  }

  // Download PDF
  static Future<void> downloadPdf(
    BuildContext context,
    Uint8List pdfBytes,
    String contributionId,
  ) async {
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
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
      final fileName = 'KoFund_Receipt_${contributionId.replaceAll('contrib_', '')}.pdf';
      final filePath = '${saveDir?.path}/$fileName';
      final file = File(filePath);
      
      await file.writeAsBytes(pdfBytes);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close saving dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt saved to Downloads folder!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      print('Receipt saved to: $filePath');
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
  static Future<void> sharePdf(
    BuildContext context,
    Uint8List pdfBytes,
    String contributionId,
  ) async {
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
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
      final fileName = 'KoFund_Receipt_${contributionId.replaceAll('contrib_', '')}.pdf';
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
    Key? key,
    required this.pdfBytes,
    required this.contributionId,
  }) : super(key: key);

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
          maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                  Icon(Icons.receipt_long, color: Colors.white, size: 24),
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
                    icon: Icon(Icons.close, color: Colors.white),
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
                    allowPrinting: true,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    pdfFileName: 'KoFund_Receipt_${widget.contributionId.replaceAll('contrib_', '')}',
                  ),
                ),
              ),
            ),

            // Action Buttons
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
                          : Icon(Icons.download_rounded),
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
                                  context,
                                  widget.pdfBytes,
                                  widget.contributionId,
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
                          : Icon(Icons.share_rounded),
                      label: Text(_isSharing ? 'Sharing...' : 'Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _isDownloading || _isSharing
                          ? null
                          : () async {
                              setState(() => _isSharing = true);
                              try {
                                await ContributionReceiptPdf.sharePdf(
                                  context,
                                  widget.pdfBytes,
                                  widget.contributionId,
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