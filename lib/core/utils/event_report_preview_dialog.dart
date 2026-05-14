import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/events/models/event_model.dart';
import 'package:kofund/features/participants/models/participant_model.dart';
import 'package:kofund/features/expenses/models/expense_model.dart';
import 'package:kofund/features/contributions/models/contribution_model.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';

class ReportPreviewDialog extends StatefulWidget {
  final EventModel event;
  final List<ParticipantModel> participants;
  final List<ExpenseModel> expenses;
  final List<ContributionModel> contributions;
  final double totalCollected;
  final double totalExpenses;
  final double balance;
  final String? communityName;

  const ReportPreviewDialog({
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
  State<ReportPreviewDialog> createState() => _ReportPreviewDialogState();
}

class _ReportPreviewDialogState extends State<ReportPreviewDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isDownloading = false;
  bool _isSharing = false;
  String? _selectedMonthId; // Format: "yyyy-MM"

  @override
  void initState() {
    super.initState();
    // Initialize month selection for monthly events
    if (widget.event.isMonthlyPayment || _isProbablyMonthly()) {
      final availableMonths = _getAvailableMonths();
      if (availableMonths.isNotEmpty) {
        _selectedMonthId = availableMonths.first;
      } else {
        _selectedMonthId = DateFormat('yyyy-MM').format(DateTime.now());
      }
    }
  }

  List<String> _getAvailableMonths() {
    final months = <String>{};
    for (var c in widget.contributions) {
      if (c.monthId != null) months.add(c.monthId!);
    }
    for (var e in widget.expenses) {
      months.add(DateFormat('yyyy-MM').format(e.expenseDate));
    }
    // Always include current month
    months.add(DateFormat('yyyy-MM').format(DateTime.now()));
    
    final list = months.toList()..sort((a, b) => b.compareTo(a));
    
    // Add "All Time" option at the beginning
    return ['all', ...list];
  }

  // Enhanced check for monthly events
  bool _isProbablyMonthly() {
    if (widget.event.isMonthlyPayment) return true;
    
    // Fallback: Check if any contribution has a monthId
    final hasMonthId = widget.contributions.any((c) => c.monthId != null);
    if (hasMonthId) return true;

    // Fallback 2: Check event title for "monthly"
    if (widget.event.title.toLowerCase().contains('monthly')) return true;

    return false;
  }

  List<ContributionModel> get _filteredContributions {
    final bool isMonthly = _isProbablyMonthly();
    if (!isMonthly || _selectedMonthId == null || _selectedMonthId == 'all') {
      return widget.contributions;
    }
    return widget.contributions.where((c) {
      if (c.monthId != null) return c.monthId == _selectedMonthId;
      return DateFormat('yyyy-MM').format(c.createdAt.toDate()) == _selectedMonthId;
    }).toList();
  }

  List<ExpenseModel> get _filteredExpenses {
    final bool isMonthly = _isProbablyMonthly();
    if (!isMonthly || _selectedMonthId == null || _selectedMonthId == 'all') {
      return widget.expenses;
    }
    return widget.expenses.where((e) {
      return DateFormat('yyyy-MM').format(e.expenseDate) == _selectedMonthId;
    }).toList();
  }

  double get _totalCollected => _filteredContributions.fold(0.0, (sum, c) => sum + c.amount);
  double get _totalExpenses => _filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
  double get _balance => _totalCollected - _totalExpenses;

  String _formatMonth(String monthId) {
    if (monthId == 'all') return 'WHOLE TIME';
    try {
      final date = DateFormat('yyyy-MM').parse(monthId);
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return monthId;
    }
  }

  Future<void> _shareReport({required bool isPdf}) async {
    setState(() => _isSharing = true);
    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (imageBytes == null) throw 'Capture failed';

      final tempDir = await getTemporaryDirectory();
      final extension = isPdf ? 'pdf' : 'png';
      final filePath = '${tempDir.path}/event_report_${widget.event.eventId}.$extension';
      final file = File(filePath);

      if (isPdf) {
        final pdfBytes = await _generatePdf(imageBytes);
        await file.writeAsBytes(pdfBytes);
      } else {
        await file.writeAsBytes(imageBytes);
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Event Summary: ${widget.event.title}',
      );
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Share failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<Uint8List> _generatePdf(Uint8List imageBytes) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          );
        },
      ),
    );
    return pdf.save();
  }

  Future<void> _downloadReport({required bool isPdf}) async {
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

      final extension = isPdf ? 'pdf' : 'png';
      final fileName = 'KoFund_Report_${widget.event.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = '${saveDir?.path}/$fileName';
      final file = File(filePath);

      if (isPdf) {
        final pdfBytes = await _generatePdf(imageBytes);
        await file.writeAsBytes(pdfBytes);
      } else {
        await file.writeAsBytes(imageBytes);
      }

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Report saved as $extension to Downloads!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Download failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showFormatPicker({required bool isSharing}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSharing ? Icons.share_rounded : Icons.download_rounded, 
                  color: AppColors.primary(context), 
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isSharing ? 'Share Report As' : 'Download Report As',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select the preferred format for your event summary.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                if (isSharing) _shareReport(isPdf: false);
                else _downloadReport(isPdf: false);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.image_rounded, color: AppColors.primary(context), size: 20),
              ),
              title: const Text('Image (PNG)', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Best for sharing on WhatsApp or Social Media'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
            const SizedBox(height: 8),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                if (isSharing) _shareReport(isPdf: true);
                else _downloadReport(isPdf: true);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
              ),
              title: const Text('PDF Document', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Best for formal records and professional printing'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMonthly = _isProbablyMonthly();
    final Color buttonBg = isDark 
        ? Colors.white.withValues(alpha: 0.12) 
        : AppColors.card(context).withValues(alpha: 0.8);
    final Color borderColor = isDark 
        ? Colors.white.withValues(alpha: 0.2) 
        : AppColors.border(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Month Picker (Visible only for Monthly Events)
          if (isMonthly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: buttonBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IntrinsicWidth(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, color: AppColors.primary(context), size: 14),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMonthId,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary(context), size: 18),
                        style: TextStyle(
                          color: AppColors.primary(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        items: _getAvailableMonths().map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(_formatMonth(m).toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMonthId = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox.shrink(),

          // Close Button (Always visible)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: buttonBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  Icons.close_rounded, 
                  color: AppColors.textPrimary(context), 
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.background(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar (Month Selector + Close Button)
          _buildHeaderBar(),

          // Visual Report Preview — scaled to fit dialog width
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                          expenses: _filteredExpenses,
                          contributions: _filteredContributions,
                          totalCollected: _totalCollected,
                          totalExpenses: _totalExpenses,
                          balance: _balance,
                          communityName: widget.communityName,
                          selectedMonthName: _selectedMonthId != null ? _formatMonth(_selectedMonthId!) : null,
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
                    onPressed: _isDownloading || _isSharing ? null : () => _showFormatPicker(isSharing: false),
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
                    onPressed: _isDownloading || _isSharing ? null : () => _showFormatPicker(isSharing: true),
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
  final String? selectedMonthName;

  const _ReportContent({
    required this.event,
    required this.participants,
    required this.expenses,
    required this.contributions,
    required this.totalCollected,
    required this.totalExpenses,
    required this.balance,
    this.communityName,
    this.selectedMonthName,
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
                  selectedMonthName != null 
                    ? selectedMonthName!.toUpperCase() 
                    : 'EVENT SUMMARY REPORT',
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
                  ...expenses.take(10).map((e) => _buildDetailItem(
                    icon: Icons.receipt_long_rounded,
                    label: e.title,
                    value: aamountFormat.format(e.amount),
                    color: Colors.redAccent,
                  )),
                  if (expenses.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        '+ ${expenses.length - 10} more expenses (truncated)',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
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





