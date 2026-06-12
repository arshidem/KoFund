import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_styles.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:collection';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/network_service.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../contributions/models/contribution_model.dart';
import '../../contributions/providers/contribution_provider.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../events/models/event_model.dart';
import 'package:kofund/core/skeleton/edit_contribution_skeleton.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/constants/app_dimensions.dart';

class EditContributionScreen extends StatefulWidget {
  final String contributionId;
  final Function(ContributionModel?) onSave;

  const EditContributionScreen({
    super.key,
    required this.contributionId,
    required this.onSave,
  });

  @override
  State<EditContributionScreen> createState() => _EditContributionScreenState();
}

class _EditContributionScreenState extends State<EditContributionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _editReasonController = TextEditingController();
  final _amountController = TextEditingController();

  // Form values
  String _paymentMethod = '';
  String? _monthId;
  bool _isMonthly = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _saving = false;

  bool get _hasAnyChanges {
    return '₹${_contribution!.amount.toStringAsFixed(2)}' !=
            '₹${_amountController.text.isNotEmpty ? _amountController.text : "0.00"}' ||
        _contribution!.paymentMethod != _paymentMethod ||
        _contribution!.eventId != _selectedEventId ||
        _isMonthly != _contribution!.isMonthlyContribution ||
        (_isMonthly && _monthId != _contribution!.monthId);
  }

  // Event selection
  String? _selectedEventId;
  List<EventModel> _availableEvents = [];

  // Store fetched contribution
  ContributionModel? _contribution;

  // Available payment methods
  final List<String> _paymentMethods = ['Cash', 'UPI'];

  // Available months for selection
  final List<String> _availableMonths = [];

  @override
  void initState() {
    super.initState();
    _generateAvailableMonths();
    _fetchContribution();
  }

  @override
  void dispose() {
    _editReasonController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data fetching
  // ---------------------------------------------------------------------------

  Future<void> _fetchContribution() async {
    try {
      debugPrint('🔄 Fetching contribution with ID: ${widget.contributionId}');

      var docRef = FirebaseFirestore.instance
          .collection('contributions')
          .doc(widget.contributionId);

      var snapshot = await docRef.get();

      // If not found, try adding 'contrib_' prefix
      if (!snapshot.exists && !widget.contributionId.startsWith('contrib_')) {
        debugPrint('⚠️ Not found, trying with "contrib_" prefix...');
        docRef = FirebaseFirestore.instance
            .collection('contributions')
            .doc('contrib_${widget.contributionId}');
        snapshot = await docRef.get();
      }

      if (!snapshot.exists) {
        throw Exception(
            'Contribution not found with ID: ${widget.contributionId}');
      }

      final data = snapshot.data();
      if (data == null) {
        throw Exception('Contribution data is invalid');
      }

      _contribution = ContributionModel.fromMap(data, snapshot.id);

      debugPrint('✅ Contribution fetched successfully');
      debugPrint('   Amount: ${_contribution!.amount}');
      debugPrint('   Payment Method: ${_contribution!.paymentMethod}');
      debugPrint('   Event ID: ${_contribution!.eventId}');
      debugPrint('   Community ID: ${_contribution!.communityId}');

      // Fetch available events for this community
      await _fetchAvailableEvents(_contribution!.communityId);

      // Initialize form values
      _amountController.text = _contribution!.amount.toStringAsFixed(2);
      _paymentMethod = _contribution!.paymentMethod;
      _selectedEventId = _contribution!.eventId;
      _isMonthly = _contribution!.isMonthlyContribution;
      _monthId = _contribution!.monthId;

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error fetching contribution: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchAvailableEvents(String communityId) async {
    try {
      debugPrint(
          '📋 Fetching events for community: $communityId from root collection');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('communityId', isEqualTo: communityId)
          .get();

      _availableEvents = querySnapshot.docs.map((doc) {
        final data = doc.data();
        debugPrint('📝 event data: $data');
        return EventModel.fromMap(data, doc.id);
      }).toList();

      debugPrint('✅ Found ${_availableEvents.length} events');

      // Ensure the current event is in the list
      if (_contribution != null &&
          !_availableEvents
              .any((p) => p.eventId == _contribution!.eventId)) {
        try {
          final rootDoc = await FirebaseFirestore.instance
              .collection('events')
              .doc(_contribution!.eventId)
              .get();

          if (rootDoc.exists) {
            final event = EventModel.fromMap(
                rootDoc.data() as Map<String, dynamic>, rootDoc.id);
            _availableEvents.add(event);
            debugPrint('➕ Added current event from root collection');
          }
        } catch (e) {
          debugPrint('⚠️ Could not fetch current event: $e');
        }
      }

      // Sort events by name
      _availableEvents.sort((a, b) => a.title.compareTo(b.title));

      for (var event in _availableEvents) {
        debugPrint(
            '📋 event: ${event.title}, Monthly: ${event.isMonthlyPayment}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching events: $e');
      _availableEvents = [];
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _isSelectedMonthly {
    if (_selectedEventId == null) return false;
    try {
      final event = _availableEvents.firstWhere(
        (p) => p.eventId == _selectedEventId,
      );
      return event.isMonthlyPayment;
    } catch (e) {
      if (_contribution != null &&
          _selectedEventId == _contribution!.eventId) {
        return _contribution!.isMonthlyContribution;
      }
      return false;
    }
  }

  void _generateAvailableMonths() {
    _availableMonths.clear();
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthId = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      _availableMonths.add(monthId);
    }
    final unique = LinkedHashSet<String>.from(_availableMonths);
    _availableMonths
      ..clear()
      ..addAll(unique);
  }

  String _formatMonthId(String monthId) {
    try {
      final parts = monthId.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final month = int.parse(parts[1]);
        final date = DateTime(int.parse(year), month, 1);
        return DateFormat('MMM yyyy').format(date);
      }
    } catch (e) {
      return monthId;
    }
    return monthId;
  }

  String _getNameById(String eventId) {
    try {
      final event = _availableEvents.firstWhere(
        (p) => p.eventId == eventId,
        orElse: () => EventModel(
          eventId: eventId,
          communityId: _contribution?.communityId ?? '',
          title: 'Event $eventId',
          description: '',
          eventDate: DateTime.now(),
          location: '',
          maxParticipants: 0,
          participantType: 'fixed',
          status: 'active',
          createdBy: '',
          createdAt: Timestamp.now(),
          eventType: 'general',
          isMonthlyPayment: false,
        ),
      );
      return event.title;
    } catch (e) {
      return 'Event $eventId';
    }
  }

  // ---------------------------------------------------------------------------
  // Save logic
  // ---------------------------------------------------------------------------

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_contribution == null) {
      SnackbarHelper.showError(context, 'Contribution data not loaded');
      return;
    }

    final amountText = _amountController.text;
    final newAmount = double.tryParse(amountText) ?? 0.0;

    bool hasChanges = newAmount != _contribution!.amount ||
        _paymentMethod != _contribution!.paymentMethod ||
        _selectedEventId != _contribution!.eventId ||
        _isMonthly != _contribution!.isMonthlyContribution ||
        _monthId != _contribution!.monthId;

    if (!hasChanges) {
      if (!mounted) return;
      SnackbarHelper.showInfo(context, 'No changes detected');
      widget.onSave(null);
      return;
    }

    // Show confirmation dialog if amount or event changed
    if (newAmount != _contribution!.amount ||
        _selectedEventId != _contribution!.eventId) {
      String changes = '';

      if (newAmount != _contribution!.amount) {
        final difference = newAmount - _contribution!.amount;
        changes +=
            'Amount: ₹${_contribution!.amount.toStringAsFixed(2)} → ₹${newAmount.toStringAsFixed(2)} (${difference > 0 ? '+' : ''}₹${difference.abs().toStringAsFixed(2)})\n';
      }

      if (_selectedEventId != _contribution!.eventId) {
        final oldName = _getNameById(_contribution!.eventId);
        final newName = _getNameById(_selectedEventId!);
        changes += 'Event: $oldName → $newName\n';
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Changes'),
          content: Text(
            'You are making the following changes:\n\n$changes\nPlease provide a reason for these changes:',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _saving = true);

    try {
      final authProvider = context.read<AppAuthProvider>();
      final currentUser = authProvider.user;

      if (currentUser == null) throw Exception('User not authenticated');

      final updatedContribution = _contribution!.copyWith(
        contributionId: widget.contributionId,
        amount: newAmount,
        paymentMethod: _paymentMethod,
        eventId: _selectedEventId ?? _contribution!.eventId,
        isMonthlyContribution: _isMonthly,
        monthId: _isMonthly ? _monthId : null,
        editReason: _editReasonController.text.trim(),
      );

      final contributionProvider = context.read<ContributionProvider>();
      await contributionProvider.updateContribution(
        updatedContribution,
        editedByUserId: currentUser.uid,
        editedByUserName: currentUser.displayName ?? 'Admin User',
        editReason: _editReasonController.text.trim(),
      );

      widget.onSave(updatedContribution);

      if (!mounted) return;
      SnackbarHelper.showSuccess(context, 'Contribution updated successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Error updating contribution: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Reusable UI builders
  // ---------------------------------------------------------------------------

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int maxLength = 100,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    bool isRequired = false,
    bool showCharacterCounter = false,
    String? Function(String?)? validator,
  }) {
    final formatters = <TextInputFormatter>[
      if (inputFormatters != null) ...inputFormatters,
      LengthLimitingTextInputFormatter(maxLength),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = maxLines > 1 ? AppDimensions.radiusLarge : 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface(context) : Colors.white,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            inputFormatters: formatters,
            validator: validator,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: isRequired ? '$label *' : label,
              hintStyle: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 15,
              ),
              prefixIcon: maxLines > 1
                  ? Align(
                      alignment: Alignment.topCenter,
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 12, top: 18),
                        child: Icon(icon, color: AppColors.primary(context), size: 22),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(left: 20, right: 12),
                      child: Icon(icon, color: AppColors.primary(context), size: 22),
                    ),
              prefixIconConstraints: BoxConstraints(
                minWidth: 40,
                minHeight: maxLines > 1 ? 0 : 40,
              ),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide(
                  color: AppColors.primary(context).withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              errorText: errorText,
              errorStyle: const TextStyle(fontSize: 12, height: 1.2),
              counterText: '',
            ),
          ),
        ),
        if (showCharacterCounter)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final currentLength = value.text.length;
                  final remaining = maxLength - currentLength;
                  return Text(
                    '$currentLength/$maxLength',
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining <= 10
                          ? Colors.orange
                          : AppColors.textSecondary(context),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface(context) : Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: AppColors.surface(context),
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textTertiary(context),
            fontSize: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(100),
            borderSide: BorderSide(
              color: AppColors.primary(context).withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 12),
            child: Icon(icon, color: AppColors.primary(context), size: 22),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        items: items,
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  Widget _buildChangeItem({
    required String label,
    required String oldValue,
    required String newValue,
    required bool hasChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hasChanged
            ? Colors.blue.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasChanged
              ? Colors.blue.withValues(alpha: 0.2)
              : AppColors.border(context).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Change indicator dot
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(
              color: hasChanged ? Colors.blue.shade600 : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasChanged
                        ? Colors.blue.shade700
                        : AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  oldValue,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasChanged
                        ? Colors.red.shade700
                        : AppColors.textPrimary(context),
                    decoration:
                        hasChanged ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasChanged) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.arrow_forward,
                          size: 12, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          newValue,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Changed badge
          if (hasChanged)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'CHANGED',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Edit Contribution',
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [_buildSaveAction()],
      body: Padding(
        padding: AppStyles.screenPadding,
        child: _isLoading
            ? EditContributionSkeleton(
                isDarkMode:
                    Theme.of(context).brightness == Brightness.dark,
              )
            : _hasError
                ? _buildErrorView()
                : _buildFormContent(),
      ),
    );
  }

  Widget _buildSaveAction() {
    return StatefulBuilder(
      builder: (context, setState) {
        return _saving
            ? Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                        AppColors.textPrimary(context)),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                child: StreamBuilder<bool>(
                  stream: NetworkService().onConnectionChanged,
                  initialData: true,
                  builder: (context, snapshot) {
                    final isOnline = snapshot.data ?? true;
                    return IconButton(
                      icon: isOnline
                          ? Icon(Icons.check,
                              color: AppColors.textPrimary(context), size: 26)
                          : Icon(Icons.wifi_off,
                              color: AppColors.textPrimary(context)
                                  .withValues(alpha: 0.7),
                              size: 26),
                      tooltip: isOnline
                          ? 'Save Changes'
                          : 'Offline - No Connection',
                      onPressed: isOnline ? _saveChanges : null,
                    );
                  },
                ),
              );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading contribution',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchContribution,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                // Event selection dropdown
                _buildEventDropdown(),
                const SizedBox(height: 16),

                // Amount field
                _buildInputField(
                  controller: _amountController,
                  label: 'Amount',
                  icon: Icons.currency_rupee,
                  hint: 'e.g., 500, 1000, 2000',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  isRequired: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Payment method dropdown
                _buildPaymentMethodDropdown(),
                const SizedBox(height: 16),

                // Month selection (only for monthly events)
                if (_isSelectedMonthly) ...[
                  _buildMonthDropdown(),
                  const SizedBox(height: 16),
                ],

                // Edit reason field
                _buildInputField(
                  controller: _editReasonController,
                  label: 'Reason for Edit',
                  icon: Icons.edit_note,
                  hint: 'Why are you making these changes?',
                  maxLines: 1,
                  maxLength: 200,
                  showCharacterCounter: true,
                  isRequired: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please provide a reason for editing';
                    }
                    final alphabetCount =
                        value.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
                    if (alphabetCount < 3) {
                      return 'Reason must have at least 3 alphabet characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Changes Summary card
          _buildChangesSummary(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Form field builders
  // ---------------------------------------------------------------------------

  Widget _buildEventDropdown() {
    // Build items list, ensuring current event is always present
    final items = List<EventModel>.from(_availableEvents);
    if (_selectedEventId != null &&
        !items.any((e) => e.eventId == _selectedEventId)) {
      items.add(EventModel(
        eventId: _selectedEventId!,
        communityId: _contribution?.communityId ?? '',
        title: _contribution?.eventName ?? 'Event $_selectedEventId',
        description: '',
        eventDate: DateTime.now(),
        location: '',
        maxParticipants: 0,
        participantType: 'fixed',
        status: 'active',
        createdBy: '',
        createdAt: Timestamp.now(),
        eventType: 'general',
        isMonthlyPayment: false,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdownField(
          value: _selectedEventId,
          hint: 'Select Event *',
          icon: Icons.assignment_outlined,
          items: items.map((event) {
            return DropdownMenuItem<String>(
              value: event.eventId,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (event.isMonthlyPayment) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Monthly',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedEventId = value;
              if (value != null) {
                try {
                  final event = _availableEvents
                      .firstWhere((p) => p.eventId == value);
                  _isMonthly = event.isMonthlyPayment;
                  if (!_isMonthly) _monthId = null;
                } catch (e) {
                  if (_contribution != null &&
                      value == _contribution!.eventId) {
                    _isMonthly = _contribution!.isMonthlyContribution;
                  } else {
                    _isMonthly = false;
                    _monthId = null;
                  }
                }
              }
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select an event';
            }
            return null;
          },
        ),
        if (_availableEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No active events found in this community',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return _buildDropdownField(
      value: _paymentMethods.contains(_paymentMethod)
          ? _paymentMethod
          : (_paymentMethods.isNotEmpty ? _paymentMethods.first : null),
      hint: 'Select Payment Method *',
      icon: Icons.payment,
      items: _paymentMethods.map((method) {
        return DropdownMenuItem<String>(
          value: method,
          child: Text(
            method,
            style: TextStyle(color: AppColors.textPrimary(context)),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) setState(() => _paymentMethod = value);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select payment method';
        }
        return null;
      },
    );
  }

  Widget _buildMonthDropdown() {
    return _buildDropdownField(
      value: _monthId != null && _availableMonths.contains(_monthId)
          ? _monthId
          : (_availableMonths.isNotEmpty ? _availableMonths.first : null),
      hint: 'Select Month *',
      icon: Icons.calendar_month,
      items: _availableMonths.map((monthId) {
        return DropdownMenuItem<String>(
          value: monthId,
          child: Text(
            _formatMonthId(monthId),
            style: TextStyle(color: AppColors.textPrimary(context)),
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _monthId = value),
      validator: (value) {
        if (_isSelectedMonthly && (value == null || value.isEmpty)) {
          return 'Please select month for monthly event';
        }
        return null;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Changes Summary
  // ---------------------------------------------------------------------------

  Widget _buildChangesSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppColors.surface(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.summarize,
                      size: 18, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                Text(
                  'Changes Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Container(
              height: 1,
              color: AppColors.border(context).withValues(alpha: 0.5),
            ),

            const SizedBox(height: 12),

            // Change items
            _buildChangeItem(
              label: 'Amount',
              oldValue: '₹${_contribution!.amount.toStringAsFixed(2)}',
              newValue:
                  '₹${_amountController.text.isNotEmpty ? _amountController.text : "0.00"}',
              hasChanged:
                  '₹${_contribution!.amount.toStringAsFixed(2)}' !=
                      '₹${_amountController.text.isNotEmpty ? _amountController.text : "0.00"}',
            ),

            const SizedBox(height: 8),

            _buildChangeItem(
              label: 'Payment Method',
              oldValue: _contribution!.paymentMethod,
              newValue: _paymentMethod,
              hasChanged: _contribution!.paymentMethod != _paymentMethod,
            ),

            const SizedBox(height: 8),

            _buildChangeItem(
              label: 'Event',
              oldValue: _getNameById(_contribution!.eventId),
              newValue: _selectedEventId != null
                  ? _getNameById(_selectedEventId!)
                  : _getNameById(_contribution!.eventId),
              hasChanged: _contribution!.eventId != _selectedEventId,
            ),

            if (_isMonthly != _contribution!.isMonthlyContribution) ...[
              const SizedBox(height: 8),
              _buildChangeItem(
                label: 'Type',
                oldValue: _contribution!.isMonthlyContribution
                    ? 'Monthly'
                    : 'One-time',
                newValue: _isMonthly ? 'Monthly' : 'One-time',
                hasChanged: true,
              ),
            ],

            if (_isMonthly && _monthId != _contribution!.monthId) ...[
              const SizedBox(height: 8),
              _buildChangeItem(
                label: 'Month',
                oldValue: _contribution!.monthId != null
                    ? _formatMonthId(_contribution!.monthId!)
                    : 'None',
                newValue:
                    _monthId != null ? _formatMonthId(_monthId!) : 'None',
                hasChanged: true,
              ),
            ],

            // No changes indicator
            if (!_hasAnyChanges)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'No changes made yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
