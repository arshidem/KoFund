// lib/features/expenses/screens/edit_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../expenses/models/expense_model.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../programs/models/program_model.dart';
import 'package:kofund/core/skeleton/edit_contribution_skeleton.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/services/network_service.dart';

class EditExpenseScreen extends StatefulWidget {
  final String expenseId;
  final Function(ExpenseModel?) onSave;

  const EditExpenseScreen({
    super.key,
    required this.expenseId,
    required this.onSave,
  });

  @override
  _EditExpenseScreenState createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _editReasonController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isSaving = false;

  ExpenseModel? _expense;
  String? _selectedProgramId;
  List<ProgramModel> _availablePrograms = [];
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();

  final List<String> _categories = [
    'food',
    'transport',
    'venue',
    'materials',
    'decorations',
    'utilities',
    'maintenance',
    'events',
    'other'
  ];

  final List<String> _paymentMethods = [
    'cash',
    'upi',
  ];

  bool get _hasAnyChanges {
    if (_expense == null) return false;
    return _expense!.title != _titleController.text.trim() ||
           _expense!.description != _descriptionController.text.trim() ||
           _expense!.amount != (double.tryParse(_amountController.text) ?? 0.0) ||
           _expense!.programId != _selectedProgramId ||
           _expense!.category != _selectedCategory ||
           _expense!.paymentMethod != _selectedPaymentMethod ||
           _expense!.expenseDate != _selectedDate;
  }

  @override
  void initState() {
    super.initState();
    _fetchExpenseAndPrograms();
  }

  Future<void> _fetchExpenseAndPrograms() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final expenseDoc = await FirebaseFirestore.instance
          .collection('expenses')
          .doc(widget.expenseId)
          .get();

      if (!expenseDoc.exists) {
        throw 'Expense not found';
      }

      _expense = ExpenseModel.fromMap(expenseDoc.data()!, expenseDoc.id);
      
      // Load programs
      final communityId = _expense!.communityId;
      final programsSnapshot = await FirebaseFirestore.instance
          .collection('programs')
          .where('communityId', isEqualTo: communityId)
          .get();

      _availablePrograms = programsSnapshot.docs
          .map((doc) => ProgramModel.fromMap(doc.data(), doc.id))
          .toList();

      // Set initial values
      _titleController.text = _expense!.title;
      _descriptionController.text = _expense!.description;
      _amountController.text = _expense!.amount.toString();
      _selectedProgramId = _expense!.programId;
      _selectedCategory = _expense!.category;
      _selectedPaymentMethod = _expense!.paymentMethod;
      _selectedDate = _expense!.expenseDate;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final currentUser = authProvider.user;

      final updatedExpense = _expense!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        programId: _selectedProgramId,
        category: _selectedCategory,
        paymentMethod: _selectedPaymentMethod,
        expenseDate: _selectedDate,
        isEdited: true,
        lastEditedByUserId: currentUser?.uid,
        lastEditedByUserName: currentUser?.displayName,
        lastEditedAt: Timestamp.now(),
        editReason: _editReasonController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(widget.expenseId)
          .update(updatedExpense.toMap());

      widget.onSave(updatedExpense);
      if (mounted) {
        Navigator.pop(context);
        SnackbarHelper.showSuccess(context, 'Expense updated successfully');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to update expense: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getProgramNameById(String id) {
    try {
      return _availablePrograms.firstWhere((p) => p.programId == id).title;
    } catch (_) {
      return 'Unknown Program';
    }
  }

  String _formatCategory(String category) {
    if (category.isEmpty) return 'None';
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash': return 'Cash';
      case 'upi': return 'UPI';
      default: return method.isNotEmpty ? method[0].toUpperCase() + method.substring(1).toLowerCase() : method;
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    FocusNode? focusNode,
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

    String displayLabel = label;
    if (isRequired && !label.trim().endsWith('*')) {
      displayLabel = '$label *';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
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
            labelText: displayLabel,
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
              horizontal: 20,
              vertical: maxLines == 1 ? 18 : 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
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
            counterText: '',
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

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border(context)),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              color: AppColors.surface(context),
            ),
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: AppColors.primary(context), size: 20),
              title: Text(
                'Expense Date *',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
              ),
              subtitle: Text(
                DateFormat('MMM dd, yyyy').format(_selectedDate),
                style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600, fontSize: 14),
              ),
              trailing: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
    if (!hasChanged) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Row(
            children: [
              Expanded(child: Text(oldValue, style: const TextStyle(color: Colors.red, decoration: TextDecoration.lineThrough, fontSize: 11))),
              const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
              Expanded(child: Text(newValue, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11))),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Edit Expense',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        StatefulBuilder(
          builder: (context, setState) {
            return _isSaving
                ? const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
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
                              ? const Icon(Icons.check, color: Colors.white, size: 26)
                              : const Icon(Icons.wifi_off, color: Colors.white70, size: 26),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _isLoading
              ? EditContributionSkeleton(isDarkMode: Theme.of(context).brightness == Brightness.dark)
              : _hasError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error loading expense', style: TextStyle(fontSize: 18, color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14)),
                          const SizedBox(height: 24),
                          ElevatedButton(onPressed: _fetchExpenseAndPrograms, child: const Text('Try Again')),
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
                                // Program Selection
                                DropdownButtonFormField<String>(
                                  initialValue: (_selectedProgramId != null && _availablePrograms.any((p) => p.programId == _selectedProgramId)) 
                                      ? _selectedProgramId 
                                      : null,
                                  dropdownColor: AppColors.surface(context),
                                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Program *',
                                    labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull), borderSide: BorderSide(color: AppColors.border(context))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull), borderSide: BorderSide(color: AppColors.border(context))),
                                    filled: true,
                                    fillColor: AppColors.surface(context),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    prefixIcon: Icon(Icons.assignment_outlined, color: AppColors.primary(context), size: 20),
                                  ),
                                  items: _availablePrograms.map((program) {
                                    return DropdownMenuItem<String>(value: program.programId, child: Text(program.title, style: TextStyle(color: AppColors.textPrimary(context))));
                                  }).toList(),
                                  onChanged: (value) => setState(() => _selectedProgramId = value),
                                  validator: (value) => value == null ? 'Please select a program' : null,
                                  hint: const Text('Select Program'),
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: _titleController,
                                  label: 'Expense Title',
                                  icon: Icons.title,
                                  hint: 'Enter expense title',
                                  maxLength: 50,
                                  isRequired: true,
                                  showCharacterCounter: true,
                                  validator: (value) => value == null || value.trim().length < 3 ? 'Small title' : null,
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(controller: _descriptionController, label: 'Description', icon: Icons.description, hint: 'Add details...', maxLines: 3, maxLength: 200),
                                const SizedBox(height: 16),
                                _buildInputField(controller: _amountController, label: 'Amount', icon: Icons.currency_rupee, hint: 'e.g. 500', keyboardType: TextInputType.number, isRequired: true),
                                const SizedBox(height: 16),
                                // Category Selection
                                DropdownButtonFormField<String>(
                                  initialValue: (_selectedCategory != null && _categories.contains(_selectedCategory!.toLowerCase())) 
                                      ? _selectedCategory!.toLowerCase() 
                                      : null,
                                  dropdownColor: AppColors.surface(context),
                                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Category *',
                                    labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull), borderSide: BorderSide(color: AppColors.border(context))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull), borderSide: BorderSide(color: AppColors.border(context))),
                                    filled: true,
                                    fillColor: AppColors.surface(context),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    prefixIcon: Icon(Icons.category_outlined, color: AppColors.primary(context), size: 20),
                                  ),
                                  items: _categories.map((cat) => DropdownMenuItem(
                                    value: cat, 
                                    child: Text(_formatCategory(cat), style: TextStyle(color: AppColors.textPrimary(context)))
                                  )).toList(),
                                  onChanged: (value) => setState(() => _selectedCategory = value),
                                  validator: (value) => value == null ? 'Required' : null,
                                  hint: Text(_selectedCategory ?? 'Select Category'),
                                ),
                                const SizedBox(height: 16),
                                // Payment Method
                                DropdownButtonFormField<String>(
                                  initialValue: (_selectedPaymentMethod != null && _paymentMethods.contains(_selectedPaymentMethod!.toLowerCase())) 
                                      ? _selectedPaymentMethod!.toLowerCase() 
                                      : null,
                                  dropdownColor: AppColors.surface(context),
                                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Payment Method *',
                                    labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull), borderSide: BorderSide(color: AppColors.border(context))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusFull), borderSide: BorderSide(color: AppColors.border(context))),
                                    filled: true,
                                    fillColor: AppColors.surface(context),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    prefixIcon: Icon(Icons.payment_outlined, color: AppColors.primary(context), size: 20),
                                  ),
                                  items: _paymentMethods.map((m) => DropdownMenuItem(
                                    value: m, 
                                    child: Text(_formatPaymentMethod(m), style: TextStyle(color: AppColors.textPrimary(context)))
                                  )).toList(),
                                  onChanged: (value) => setState(() => _selectedPaymentMethod = value),
                                  validator: (value) => value == null ? 'Required' : null,
                                  hint: Text(_selectedPaymentMethod ?? 'Select Method'),
                                ),
                                const SizedBox(height: 16),
                                _buildDatePickerField(),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: _editReasonController,
                                  label: 'Reason for Edit',
                                  icon: Icons.edit_note,
                                  hint: 'Why are you editing?',
                                  isRequired: true,
                                  validator: (value) => value == null || value.trim().length < 3 ? 'Provide reason' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Changes Summary
                          if (_hasAnyChanges)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildChangeItem(label: 'Title', oldValue: _expense!.title, newValue: _titleController.text, hasChanged: _expense!.title != _titleController.text),
                                    _buildChangeItem(label: 'Amount', oldValue: _expense!.amount.toString(), newValue: _amountController.text, hasChanged: _expense!.amount != double.tryParse(_amountController.text)),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _saveChanges,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary(context), padding: const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _editReasonController.dispose();
    _descriptionController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
