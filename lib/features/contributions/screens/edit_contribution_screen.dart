// edit_contribution_screen.dart
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

class EditContributionScreen extends StatefulWidget {
  final String contributionId;
  final Function(ContributionModel?) onSave;

  const EditContributionScreen({
    super.key,
    required this.contributionId,
    required this.onSave,
  });

  @override
  _EditContributionScreenState createState() => _EditContributionScreenState();
}

class _EditContributionScreenState extends State<EditContributionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _editReasonController = TextEditingController();
  final _aamountController = TextEditingController();

  // Form values
  String _paymentMethod = '';
  String? _monthId;
  bool _isMonthlyy = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _saving = false;
  bool get _hasAnyChanges {
  return '₹${_contribution!.amount.toStringAsFixed(2)}' != 
         '₹${_aamountController.text.isNotEmpty ? _aamountController.text : "0.00"}' ||
      _contribution!.paymentMethod != _paymentMethod ||
      _contribution!.eventId != _selecteId ||
      _isMonthlyy != _contribution!.isMonthlyContribution ||
      (_isMonthlyy && _monthId != _contribution!.monthId);
}
  // NEW: event selection
  String? _selecteId;
  List<EventModel> _availableEvents = [];
  
  // Store fetched contribution
  ContributionModel? _contribution;

  // Available payment methods
  final List<String> _paymentMethods = [
    'Cash',
    'UPI',
  ];

  // Available months for selection
  final List<String> _availableMonths = [];

  // Add this method for scrolling to errors
  void _scrollToFirstError() {
    final context = _formKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _generateAvailableMonths();
    _fetchContributionAns();
  }

  Future<void> _fetchContributionAns() async {
    try {
      debugPrint('🔄 Fetching contribution with ID: ${widget.contributionId}');
      
      // First try with the given ID
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
        throw Exception('Contribution not found with ID: ${widget.contributionId}');
      }
      
      final data = snapshot.data();
      if (data == null) {
        throw Exception('Contribution data is invalid');
      }
      
      // Create ContributionModel from Firestore data
      _contribution = ContributionModel.fromMap(data, snapshot.id);
      
      debugPrint('✅ Contribution fetched successfully');
      debugPrint('   Amount: ${_contribution!.amount}');
      debugPrint('   Payment Method: ${_contribution!.paymentMethod}');
      debugPrint('   event ID: ${_contribution!.eventId}');
      debugPrint('   Community ID: ${_contribution!.communityId}');
      
      // Fetch available events for this community
      await _fetchAvailabls(_contribution!.communityId);
      
      // Initialize form values
      _aamountController.text = _contribution!.amount.toStringAsFixed(2);
      _paymentMethod = _contribution!.paymentMethod;
      _selecteId = _contribution!.eventId;
      _isMonthlyy = _contribution!.isMonthlyContribution;
      _monthId = _contribution!.monthId;
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      debugPrint('❌ Error fetching contribution: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchAvailabls(String communityId) async {
    try {
      debugPrint('📋 Fetching events for community: $communityId');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('events')
          .where('status', whereIn: ['active', 'ongoing'])
          .get();
      
      _availableEvents = querySnapshot.docs.map((doc) {
        final data = doc.data();
        debugPrint('📝 event data: $data');
        return EventModel.fromMap(data, doc.id);
      }).toList();
      
      debugPrint('✅ Found ${_availableEvents.length} events');

      // If no events found in subcollection, try root events collection
      if (_availableEvents.isEmpty) {
        debugPrint('⚠️ No events in subcollection, trying root collection...');
        final rootQuery = await FirebaseFirestore.instance
            .collection('events')
            .where('communityId', isEqualTo: communityId)
            .where('status', whereIn: ['active', 'ongoing'])
            .get();
        
        _availableEvents = rootQuery.docs.map((doc) {
          return EventModel.fromMap(doc.data(), doc.id);
        }).toList();
        
        debugPrint('✅ Found ${_availableEvents.length} events in root collection');
      }
      
      // Ensure the current event is in the list
      if (_contribution != null && !_availableEvents.any((p) => p.eventId == _contribution!.eventId)) {
        // Try to fetch the specific event to add to list
        try {
          // Try community subcollection first
          final doc = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .collection('events')
              .doc(_contribution!.eventId)
              .get();
          
          if (doc.exists) {
            final event = EventModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            _availableEvents.add(event);
            debugPrint('➕ Added current event from subcollection');
          } else {
            // Try root collection
            final rooDoc = await FirebaseFirestore.instance
                .collection('events')
                .doc(_contribution!.eventId)
                .get();
            
            if (rooDoc.exists) {
              final event = EventModel.fromMap(rooDoc.data() as Map<String, dynamic>, rooDoc.id);
              _availableEvents.add(event);
              debugPrint('➕ Added current event from root collection');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Could not fetch current event: $e');
        }
      }
      
      // Sort events by name
      _availableEvents.sort((a, b) => a.title.compareTo(b.title));
      
      // Debug: Print event Types
      for (var event in _availableEvents) {
        debugPrint('📋 event: ${event.title}, Monthly: ${event.isMonthlyPayment}');
      }
      
    } catch (e) {
      debugPrint('❌ Error fetching events: $e');
      _availableEvents = [];
    }
  }

  // Check if currently selected event is a monthly payment event
  bool get _isSelecteMonthly {
    if (_selecteId == null) return false;
    
    try {
      final event = _availableEvents.firstWhere(
        (p) => p.eventId == _selecteId,
      );
      return event.isMonthlyPayment;
    } catch (e) {
      // If event not found, check the contribution's original event
      if (_contribution != null && _selecteId == _contribution!.eventId) {
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

    // Remove duplicates IN-PLACE
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

  // Helper function to get event name by ID
  String _geNnameById(String eventId) {
    try {
      final event = _availableEvents.firstWhere(
        (p) => p.eventId == eventId,
        orElse: () => EventModel(
          eventId: eventId,
          communityId: _contribution?.communityId ?? '',
          title: 'event $eventId',
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
      return 'event $eventId';
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_contribution == null) {
      SnackbarHelper.showError(context, 'Contribution data not loaded');
      return;
    }

    // Parse amount
    final aamountText = _aamountController.text;
    final newAamount = double.tryParse(aamountText) ?? 0.0;

    // Check if there are actual changes
    bool hasChanges = newAamount != _contribution!.amount ||
        _paymentMethod != _contribution!.paymentMethod ||
        _selecteId != _contribution!.eventId ||
        _isMonthlyy != _contribution!.isMonthlyContribution ||
        _monthId != _contribution!.monthId;

    if (!hasChanges) {
      if (!mounted) return;
      SnackbarHelper.showInfo(context, 'No changes detected');
      widget.onSave(null);
      return;
    }

    // Show confirmation dialog if amount or event changed
    if (newAamount != _contribution!.amount || _selecteId != _contribution!.eventId) {
      String changes = '';
      
      if (newAamount != _contribution!.amount) {
        final difference = newAamount - _contribution!.amount;
        changes += 'Amount: ₹${_contribution!.amount.toStringAsFixed(2)} → ₹${newAamount.toStringAsFixed(2)} (${difference > 0 ? '+' : ''}₹${difference.abs().toStringAsFixed(2)})\n';
      }
      
      if (_selecteId != _contribution!.eventId) {
        final olName = _geNnameById(_contribution!.eventId);
        final neName = _geNnameById(_selecteId!);
        
        changes += 'event: $olName → $neName\n';
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

      if (confirmed != true) {
        return;
      }
    }

    setState(() => _saving = true);

    try {
      // Get current user info
      final authProvider = context.read<AppAuthProvider>();
      final currentUser = authProvider.user;
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create updated contribution model
      final updatedContribution = _contribution!.copyWith(
        contributionId: widget.contributionId,
        amount: newAamount,
        paymentMethod: _paymentMethod,
        eventId: _selecteId ?? _contribution!.eventId,
        isMonthlyContribution: _isMonthlyy,
        monthId: _isMonthlyy ? _monthId : null,
        editReason: _editReasonController.text.trim(),
      );

      // Call provider to update
      final contributionProvider = context.read<ContributionProvider>();
      await contributionProvider.updateContribution(
        updatedContribution,
        editedByUserId: currentUser.uid,
        editedByUserName: currentUser.displayName ?? 'Admin User',
        editReason: _editReasonController.text.trim(),
      );

      // Call onSave callback
      widget.onSave(updatedContribution);
      
      if (!mounted) return;
      SnackbarHelper.showSuccess(context, 'Contribution updated successfully');
      
      // Navigate back
      Navigator.pop(context);
      
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Error updating contribution: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

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
    final List<TextInputFormatter> formatters = [
      if (inputFormatters != null) ...inputFormatters,
      LengthLimitingTextInputFormatter(maxLength),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
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
            fontSize: 14,
          ),
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            labelStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14,
            ),
            floatingLabelStyle: TextStyle(
              color: AppColors.primary(context),
              fontWeight: FontWeight.w600,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: maxLines > 1 ? 13 : 14,
            ),
            prefixIcon: Icon(
              icon,
              color: AppColors.primary(context),
              size: 20,
            ),
            filled: true,
            fillColor: AppColors.surface(context),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 6,
              vertical: maxLines == 1 ? 18 : 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primary(context),
                width: 2,
              ),
            ),
            errorText: errorText,
            errorStyle: const TextStyle(
              fontSize: 12,
              height: 1.2,
            ),
            counterText: showCharacterCounter ? '' : null,
          ),
        ),
        
        if (showCharacterCounter)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
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
                      fontSize: 13,
                      color: remaining <= 10 
                        ? Colors.orange 
                        : AppColors.textSecondary(context),
                      fontWeight: remaining <= 10 ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
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
            color: hasChanged
                ? Colors.blue.shade600
                : Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
        ),
        
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
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
              
              // Old Value
              Text(
                oldValue,
                style: TextStyle(
                  fontSize: 14,
                  color: hasChanged
                      ? Colors.red.shade700
                      : AppColors.textPrimary(context),
                  decoration: hasChanged
                      ? TextDecoration.lineThrough
                      : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              // New Value (if changed)
              if (hasChanged) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: Colors.green.shade700,
                    ),
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
  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Edit Contribution',
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: AppColors.textPrimary(context),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        StatefulBuilder(
          builder: (context, setState) {
            return _saving
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.textPrimary(context)),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: StreamBuilder<bool>(
                      stream: NetworkService().onConnectionChanged,
                      initialData: true,
                      builder: (context, snapshot) {
                        final bool isOnline = snapshot.data ?? true;
                        
                        return IconButton(
                          icon: isOnline
                              ? Icon(Icons.check, color: AppColors.textPrimary(context), size: 26)
                              : Icon(Icons.wifi_off, color: AppColors.textPrimary(context).withValues(alpha: 0.7), size: 26),
                          tooltip: isOnline 
                              ? 'Save Changes'
                              : 'Offline - No Connection',
                          onPressed: isOnline ? _saveChanges : null,
                        );
                      },
                    ),
                  );
          },
        ),
      ],
      body: Padding(
          padding: AppStyles.screenPadding,
          child: _isLoading
               ? EditContributionSkeleton(
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
          )
              : _hasError
                  ? Center(
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
                            onPressed: _fetchContributionAns,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary(context),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                        

                       

                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // event Selection Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'event *',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    DropdownButtonFormField<String>(
                                      initialValue: _selecteId,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppColors.border(context)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppColors.border(context)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: AppColors.primary(context),
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: AppColors.surface(context),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 16,
                                        ),
                                      ),
                                      items: _availableEvents.map((event) {
                                        return DropdownMenuItem<String>(
                                          value: event.eventId,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.center,
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
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
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
                                          _selecteId = value;

                                          if (value != null) {
                                            try {
                                              final event = _availableEvents.firstWhere(
                                                (p) => p.eventId == value,
                                              );
                                              _isMonthlyy = event.isMonthlyPayment;
                                              if (!_isMonthlyy) {
                                                _monthId = null;
                                              }
                                            } catch (e) {
                                              if (_contribution != null && value == _contribution!.eventId) {
                                                _isMonthlyy = _contribution!.isMonthlyContribution;
                                              } else {
                                                _isMonthlyy = false;
                                                _monthId = null;
                                              }
                                            }
                                          }
                                        });
                                      },

                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a event';
                                        }
                                        return null;
                                      },

                                      hint: const Text('Select event'),
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
                                ),

                                const SizedBox(height: 16),

                                // Amount Field
                                _buildInputField(
                                  controller: _aamountController,
                                  label: 'Amount',
                                  icon: Icons.currency_rupee,
                                  hint: 'e.g., 500, 1000, 2000',
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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

                                // Payment Method Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Payment Method *',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      initialValue: _paymentMethods.contains(_paymentMethod)
                                          ? _paymentMethod
                                          : (_paymentMethods.isNotEmpty ? _paymentMethods.first : null),
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppColors.border(context)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppColors.border(context)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: AppColors.primary(context),
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: AppColors.surface(context),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 16,
                                        ),
                                      ),
                                      items: _paymentMethods.map((method) {
                                        return DropdownMenuItem<String>(
                                          value: method,
                                          child: Text(
                                            method,
                                            style: TextStyle(
                                              color: AppColors.textPrimary(context),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _paymentMethod = value);
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select payment method';
                                        }
                                        return null;
                                      },
                                      hint: const Text('Select Payment Method'),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Month Selection (only for monthly events)
                                if (_isSelecteMonthly) ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Month *',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green[50],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Monthly event',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        initialValue: _monthId != null && _availableMonths.contains(_monthId)
                                            ? _monthId
                                            : (_availableMonths.isNotEmpty ? _availableMonths.first : null),
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: AppColors.border(context)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: AppColors.border(context)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: AppColors.primary(context),
                                              width: 2,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: AppColors.surface(context),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 16,
                                          ),
                                          hintText: 'Select Month',
                                        ),
                                        items: _availableMonths.map((monthId) {
                                          return DropdownMenuItem<String>(
                                            value: monthId,
                                            child: Text(
                                              _formatMonthId(monthId),
                                              style: TextStyle(
                                                color: AppColors.textPrimary(context),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() => _monthId = value);
                                        },
                                        validator: (value) {
                                          if (_isSelecteMonthly && (value == null || value.isEmpty)) {
                                            return 'Please select month for monthly event';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Edit Reason Field
                                _buildInputField(
                                  controller: _editReasonController,
                                  label: 'Reason for Edit',
                                  icon: Icons.edit_note,
                                  hint: 'Why are you making these changes?',
                                  maxLines: 2,
                                  maxLength: 200,
                                  showCharacterCounter: true,
                                  isRequired: true,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please provide a reason for editing';
                                    }
                                    final alphabetCount = value.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
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

                          // Changes Summary
                      Card(
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  color: AppColors.surface(context), // ✅ Set the background color here
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.summarize,
                size: 18,
                color: Colors.blue.shade700,
              ),
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
        
        // Divider
        Container(
          height: 1,
          color: AppColors.border(context).withValues(alpha: 0.5),
        ),
        
        const SizedBox(height: 12),
        
        // Change Items
        Column(
          children: [
            _buildChangeItem(
              label: 'Amount',
              oldValue: '₹${_contribution!.amount.toStringAsFixed(2)}',
              newValue: '₹${_aamountController.text.isNotEmpty ? _aamountController.text : "0.00"}',
              hasChanged: '₹${_contribution!.amount.toStringAsFixed(2)}' != '₹${_aamountController.text.isNotEmpty ? _aamountController.text : "0.00"}',
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
              label: 'event',
              oldValue: _geNnameById(_contribution!.eventId),
              newValue: _selecteId != null
                  ? _geNnameById(_selecteId!)
                  : _geNnameById(_contribution!.eventId),
              hasChanged: _contribution!.eventId != _selecteId,
            ),
            
            if (_isMonthlyy != _contribution!.isMonthlyContribution) ...[
              const SizedBox(height: 8),
              _buildChangeItem(
                label: 'type',
                oldValue: _contribution!.isMonthlyContribution
                    ? 'Monthly'
                    : 'One-time',
                newValue: _isMonthlyy ? 'Monthly' : 'One-time',
                hasChanged: true,
              ),
            ],
            
            if (_isMonthlyy && _monthId != _contribution!.monthId) ...[
              const SizedBox(height: 8),
              _buildChangeItem(
                label: 'Month',
                oldValue: _contribution!.monthId != null
                    ? _formatMonthId(_contribution!.monthId!)
                    : 'None',
                newValue: _monthId != null ? _formatMonthId(_monthId!) : 'None',
                hasChanged: true,
              ),
            ],
          ],
        ),
        
        // No Changes Indicator (optional)
        if (!_hasAnyChanges)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
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
),

                          const SizedBox(height: 24),

                          // Action Buttons
                          Row(
                            children: [
                            
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saveChanges,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary(context),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Save Changes'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
    );
  }

  @override
  void dispose() {
    _editReasonController.dispose();
    _aamountController.dispose();
    super.dispose();
  }
}







