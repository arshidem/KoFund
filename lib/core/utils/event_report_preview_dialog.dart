import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/events/models/event_model.dart';
import 'package:kofund/features/participants/models/participant_model.dart';
import 'package:kofund/features/expenses/models/expense_model.dart';
import 'package:kofund/features/contributions/models/contribution_model.dart';

class eportPreviewDialog extends StatefulWidget {
  final EventModel event;
  final List<ParticipantModel> participants;
  final List<ExpenseModel> expenses;
  final List<ContributionModel> contributions;
  final double totalCollected;
  final double totalExpenses;
  final double balance;
  final String? communityName;

  const eportPreviewDialog({
    super.key,
    required this.event,
    required this.participants,
    required this.expenses,
    required this.contributions,
    required this.totalCollected,
    required this.totalExpenses,
    required this.balance,
    this.communityName,
  });

  @override
  State<eportPreviewDialog> createState() => _eportPreviewDialogState();
}

class _eportPreviewDialogState extends State<eportPreviewDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isDownloading = false;
  bool _isSharing = false;

  Future<void> _shareReport() async {
    setState(() => _isSharing = true);
    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (imageBytes == null) throw 'Capture failed';

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/event_report_${widget.event.eventId}.png';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Event Summary: ${widget.event.title}',
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

  Future<void> _downloadReport() async {
    setState(() => _isDownloading = true);
    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (imageBytes == null) throw 'Capture failed';

      Directory? saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) saveDir = await getExternalStorageDirectory();
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final filePath = '${saveDir?.path}/KoFund_Report_${widget.event.eventId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report saved to Downloads!'), backgroundColor: Colors.green),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              
              // Visual Report Preview — scaled to fit dialog width
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(builder: (context, constraints) {
                      const reportWidth = 360.0;
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: reportWidth,
                          child: Screenshot(
                            controller: _screenshotController,
                            child: _ReportContent(
                              event: widget.event,
                              participants: widget.participants,
                              expenses: widget.expenses,
                              contributions: widget.contributions,
                              totalCollected: widget.totalCollected,
                              totalExpenses: widget.totalExpenses,
                              balance: widget.balance,
                              communityName: widget.communityName,
                            ),
                          ),
                        ),
                      );
                    }),
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
                        onPressed: _isDownloading || _isSharing ? null : _downloadReport,
                        icon: _isDownloading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.download_rounded, color: AppColors.textPrimary(context), size: 18),
                        label: Text(_isDownloading ? 'Saving...' : 'Download', 
                                    style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: AppColors.border(context), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading || _isSharing ? null : _shareReport,
                        icon: _isSharing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                            : const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                        label: Text(_isSharing ? 'Sharing...' : 'Share', 
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Close Button
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(context), size: 20),
              onPressed: () => Navigator.pop(context),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  final EventModel event;
  final List<ParticipantModel> participants;
  final List<ExpenseModel> expenses;
  final List<ContributionModel> contributions;
  final double totalCollected;
  final double totalExpenses;
  final double balance;
  final String? communityName;

  const _ReportContent({
    required this.event,
    required this.participants,
    required this.expenses,
    required this.contributions,
    required this.totalCollected,
    required this.totalExpenses,
    required this.balance,
    this.communityName,
  });

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF00BFA6);
    const darkTextColor = Color(0xFF0D1B2A);
    final dateFormat = DateFormat('dd MMM yyyy • hh:mm a');
    final aamountFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          // Decorative Grids (Top Right)
          Positioned(
            top: 24,
            right: 20,
            child: _buildDotsGrid(),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Community Label
                if (communityName != null)
                  Text(
                    communityName!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: tealColor.withValues(alpha: 0.5),
                      letterSpacing: 2.0,
                    ),
                  ),
                const SizedBox(height: 4),

                // Ttitle
                Text(
                  event.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: darkTextColor,
                    letterSpacing: 0.5,
                    height: 1.1,
                  ),
                ),
                Text(
                  'EVENT SUMMARY REPORT',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: tealColor.withValues(alpha: 0.6),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Badge Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tealColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.group, size: 10, color: tealColor),
                          const SizedBox(width: 4),
                          Text(
                            '${participants.length} MEMBERS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: tealColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Financial Cards
                Row(
                  children: [
                    _buildMetricBox('COLLECTED', totalCollected, tealColor),
                    const SizedBox(width: 8),
                    _buildMetricBox('EXPENSES', totalExpenses, Colors.redAccent),
                  ],
                ),
                const SizedBox(height: 8),
                _buildBalanceBox(balance, tealColor),

                const SizedBox(height: 20),

                // Transaction Details Header
                _buildSectionHeader('BREAKDOWN'),
                const SizedBox(height: 10),

                if (expenses.isNotEmpty) ...[
                  ...expenses.map((e) => _buildDetailItem(
                    icon: Icons.receipt_long_rounded,
                    label: e.title,
                    value: aamountFormat.format(e.amount),
                    color: Colors.redAccent,
                  )),
                  const Divider(height: 32),
                ],

                // Participants
                ...participants.map((p) {
                   final double paid = contributions
                      .where((c) => c.userId == p.userId)
                      .fold(0.0, (double sum, c) => sum + c.amount);
                   return _buildMemberItem(
                     name: p.userName ?? 'User',
                     value: aamountFormat.format(paid),
                     color: tealColor,
                   );
                }),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: tealColor,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/logos/KoFund.png',
                        height: 15,
                        color: Colors.white,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Verified by KoFund • ${dateFormat.format(DateTime.now())}',
                      style: TextStyle(fontSize: 8, color: Colors.grey[400], fontWeight: FontWeight.bold, letterSpacing: 0.5),
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

  Widget _buildReportIcon(Color color) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Center(
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildMetricBox(String label, double amount, Color color) {
    final format = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(format.format(amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceBox(double amount, Color color) {
    final format = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Text('CURRENT BALANCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(format.format(amount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey[400], letterSpacing: 1.5)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: Colors.grey[100])),
      ],
    );
  }

  Widget _buildDetailItem({required IconData icon, required String label, required String value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D1B2A)))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0D1B2A))),
        ],
      ),
    );
  }

  Widget _buildMemberItem({required String name, required String value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _buildAvatar(name, color),
          const SizedBox(width: 10),
          Expanded(child: Text(_toCapitalized(name), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D1B2A)))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0D1B2A))),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _toCapitalized(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildDotsGrid() {
    return Column(
      children: List.generate(3, (i) => Row(
        children: List.generate(3, (j) => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
        )),
      )),
    );
  }
}





