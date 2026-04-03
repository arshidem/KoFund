// lib/features/expenses/screens/edit_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/network_service.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../expenses/models/expense_model.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../programs/models/program_model.dart';
import '../../programs/providers/program_provider.dart';
import 'package:kofund/core/skeleton/edit_contribution_skeleton.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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
    'Food',
    'Transport',
    'Utilities',
    'Materials',
    'Events',
    'Maintenance',
    'Others'
  ];

  final List<String> _paymentMethods = [
    'Cash',
    'UPI',
    'Bank Transfer',
    'Cheque'
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

  String _formatCategory(String category) => category;
  String _formatPaymentMethod(String method) => method;

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
    String? hint,
    int? maxLength,
    bool showCharacterCounter = false,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${isRequired ? ' *' : ''}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary(context), size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            filled: true,
            fillColor: AppColors.surface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            counterText: showCharacterCounter ? null : '',
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border(context)),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surface(context),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.primary(context), size: 20),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: TextStyle(color: AppColors.textPrimary(context)),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
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
        if (!_isLoading)
          _isSaving 
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              )
            : IconButton(
                icon: const Icon(Icons.check, color: Colors.white, size: 26),
                onPressed: _saveChanges,
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Program *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedProgramId,
                                      dropdownColor: AppColors.surface(context),
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border(context))),
                                        filled: true,
                                        fillColor: AppColors.surface(context),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                      ),
                                      items: _availablePrograms.map((program) {
                                        return DropdownMenuItem<String>(value: program.programId, child: Text(program.title, style: TextStyle(color: AppColors.textPrimary(context))));
                                      }).toList(),
                                      onChanged: (value) => setState(() => _selectedProgramId = value),
                                      validator: (value) => value == null ? 'Please select a program' : null,
                                      hint: const Text('Select Program'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: _titleController,
                                  label: 'Expense Title',
                                  icon: Icons.title,
                                  hint: 'Enter expense title',
                                  maxLength: 50,
                                  isRequired: true,
                                  validator: (value) => value == null || value.trim().length < 3 ? 'Small title' : null,
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(controller: _descriptionController, label: 'Description', icon: Icons.description, hint: 'Add details...', maxLines: 3, maxLength: 200),
                                const SizedBox(height: 16),
                                _buildInputField(controller: _amountController, label: 'Amount', icon: Icons.currency_rupee, hint: 'e.g. 500', keyboardType: TextInputType.number, isRequired: true),
                                const SizedBox(height: 16),
                                // Category Selection
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Category *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedCategory,
                                      dropdownColor: AppColors.surface(context),
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border(context))),
                                        filled: true,
                                        fillColor: AppColors.surface(context),
                                      ),
                                      items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: TextStyle(color: AppColors.textPrimary(context))))).toList(),
                                      onChanged: (value) => setState(() => _selectedCategory = value),
                                      validator: (value) => value == null ? 'Required' : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Payment Method
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Payment Method *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedPaymentMethod,
                                      dropdownColor: AppColors.surface(context),
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border(context))),
                                        filled: true,
                                        fillColor: AppColors.surface(context),
                                      ),
                                      items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: TextStyle(color: AppColors.textPrimary(context))))).toList(),
                                      onChanged: (value) => setState(() => _selectedPaymentMethod = value),
                                      validator: (value) => value == null ? 'Required' : null,
                                    ),
                                  ],
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
