// edit_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/network_service.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../expenses/models/expense_model.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../auth/providers/app_auth_provider.dart';
import '../../programs/models/program_model.dart';
import '../../programs/providers/program_provider.dart';
import 'package:kofund/core/skeleton/edit_contribution_skeleton.dart';

class EditExpenseScreen extends StatefulWidget {
  final String expenseId;
  final Function(ExpenseModel?) onSave;

  const EditExpenseScreen({
    Key? key,
    required this.expenseId,
    required this.onSave,
  }) : super(key: key);

  @override
  _EditExpenseScreenState createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _editReasonController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  // Form values
  String? _selectedProgramId;
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _hasError = false;
  bool _saving = false;
  String _errorMessage = '';
  bool get _hasAnyChanges {
    return '₹${_expense!.amount.toStringAsFixed(2)}' != 
           '₹${_amountController.text.isNotEmpty ? _amountController.text : "0.00"}' ||
        _titleController.text.trim() != _expense!.title ||
        _descriptionController.text.trim() != _expense!.description ||
        _selectedProgramId != _expense!.programId ||
        _selectedCategory != _expense!.category ||
        _selectedPaymentMethod != _expense!.paymentMethod ||
        _selectedDate != _expense!.expenseDate;
  }
  
  // Store fetched expense
  ExpenseModel? _expense;
  List<ProgramModel> _availablePrograms = [];

  // Available categories
  final List<String> _categories = [
    'food',
    'transport',
    'venue',
    'materials',
    'decorations',
    'other'
  ];

  // Available payment methods
  final List<String> _paymentMethods = [
    'cash',
    'upi',
  ];

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
    _fetchExpenseAndPrograms();
  }

  Future<void> _fetchExpenseAndPrograms() async {
    try {
      print('🔄 Fetching expense with ID: ${widget.expenseId}');
      
      // First try with the given ID
      var docRef = FirebaseFirestore.instance
          .collection('expenses')
          .doc(widget.expenseId);
      
      var snapshot = await docRef.get();
      
      // If not found, try adding 'expense_' prefix
      if (!snapshot.exists && !widget.expenseId.startsWith('expense_')) {
        print('⚠️ Not found, trying with "expense_" prefix...');
        docRef = FirebaseFirestore.instance
            .collection('expenses')
            .doc('expense_${widget.expenseId}');
        snapshot = await docRef.get();
      }
      
      if (!snapshot.exists) {
        throw Exception('Expense not found with ID: ${widget.expenseId}');
      }
      
      final data = snapshot.data();
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Expense data is invalid');
      }
      
      // Create ExpenseModel from Firestore data
      _expense = ExpenseModel.fromMap(data, snapshot.id);
      
      print('✅ Expense fetched successfully');
      print('   Title: ${_expense!.title}');
      print('   Amount: ${_expense!.amount}');
      print('   Program ID: ${_expense!.programId}');
      print('   Community ID: ${_expense!.communityId}');
      
      // Fetch available programs for this community
      await _fetchAvailablePrograms(_expense!.communityId);
      
      // Initialize form values
      _titleController.text = _expense!.title;
      _descriptionController.text = _expense!.description;
      _amountController.text = _expense!.amount.toStringAsFixed(2);
      _selectedProgramId = _expense!.programId;
      _selectedCategory = _expense!.category;
      _selectedPaymentMethod = _expense!.paymentMethod;
      _selectedDate = _expense!.expenseDate;
 
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('❌ Error fetching expense: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchAvailablePrograms(String communityId) async {
    try {
      print('📋 Fetching programs for community: $communityId');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('programs')
          .where('status', whereIn: ['active', 'ongoing'])
          .get();
      
      _availablePrograms = querySnapshot.docs.map((doc) {
        return ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      print('✅ Found ${_availablePrograms.length} programs');
      
      // If no programs found in subcollection, try root programs collection
      if (_availablePrograms.isEmpty) {
        print('⚠️ No programs in subcollection, trying root collection...');
        final rootQuery = await FirebaseFirestore.instance
            .collection('programs')
            .where('communityId', isEqualTo: communityId)
            .where('status', whereIn: ['active', 'ongoing'])
            .get();
        
        _availablePrograms = rootQuery.docs.map((doc) {
          return ProgramModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        print('✅ Found ${_availablePrograms.length} programs in root collection');
      }
      
      // Ensure the current program is in the list
      if (_expense != null && !_availablePrograms.any((p) => p.programId == _expense!.programId)) {
        try {
          final programDoc = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .collection('programs')
              .doc(_expense!.programId)
              .get();
          
          if (programDoc.exists) {
            final program = ProgramModel.fromMap(programDoc.data() as Map<String, dynamic>, programDoc.id);
            _availablePrograms.add(program);
            print('➕ Added current program from subcollection');
          } else {
            final rootProgramDoc = await FirebaseFirestore.instance
                .collection('programs')
                .doc(_expense!.programId)
                .get();
            
            if (rootProgramDoc.exists) {
              final program = ProgramModel.fromMap(rootProgramDoc.data() as Map<String, dynamic>, rootProgramDoc.id);
              _availablePrograms.add(program);
              print('➕ Added current program from root collection');
            }
          }
        } catch (e) {
          print('⚠️ Could not fetch current program: $e');
        }
      }
      
      // Sort programs by name
      _availablePrograms.sort((a, b) => a.title.compareTo(b.title));
      
    } catch (e) {
      print('❌ Error fetching programs: $e');
      _availablePrograms = [];
    }
  }

  // Helper function to get program name by ID
  String _getProgramNameById(String programId) {
    try {
      final program = _availablePrograms.firstWhere(
        (p) => p.programId == programId,
        orElse: () => ProgramModel(
          programId: programId,
          communityId: _expense?.communityId ?? '',
          title: 'Program $programId',
          description: '',
          programDate: DateTime.now(),
          location: '',
          maxParticipants: 0,
          participantType: 'fixed',
          status: 'active',
          createdBy: '',
          createdAt: Timestamp.now(),
          programType: 'general',
          isMonthlyPaymentProgram: false,
        ),
      );
      return program.title;
    } catch (e) {
      return 'Program $programId';
    }
  }

  // Format category name for display
  String _formatCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food': return 'Food & Beverages';
      case 'transport': return 'Transportation';
      case 'venue': return 'Venue Rental';
      case 'materials': return 'Materials & Supplies';
      case 'decorations': return 'Decorations';
      case 'other': return 'Other Expenses';
      default: return category;
    }
  }

  // Format payment method for display
  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash': return 'Cash';
      case 'upi': return 'UPI';
      default: return method;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary(context),
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary(context),
            ),
            dialogBackgroundColor: AppColors.card(context),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_expense == null) {
      SnackbarHelper.showError(context, 'Expense data not loaded');
      return;
    }

    // Get current user info
    final authProvider = context.read<AppAuthProvider>();
    final currentUser = authProvider.user;
    
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Check if user is admin
    final bool isAdmin = currentUser.isAdmin == true && currentUser.isApproved == true;

    print('👤 User is Admin: $isAdmin');
    print('📊 Current expense status: ${_expense!.status}');

    // Parse amount
    final amountText = _amountController.text;
    final newAmount = double.tryParse(amountText) ?? 0.0;

    // Check if there are actual changes
    bool hasChanges = newAmount != _expense!.amount ||
        _titleController.text.trim() != _expense!.title ||
        _descriptionController.text.trim() != _expense!.description ||
        _selectedProgramId != _expense!.programId ||
        _selectedCategory != _expense!.category ||
        _selectedPaymentMethod != _expense!.paymentMethod ||
        _selectedDate != _expense!.expenseDate;

    if (!hasChanges) {
      if (!mounted) return;
      SnackbarHelper.showInfo(context, 'No changes detected');
      widget.onSave(null);
      return;
    }
    
    // Get edit reason
    String editReason = _editReasonController.text.trim();
    if (editReason.isEmpty) {
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Please provide a reason for editing');
      return;
    }

    setState(() => _saving = true);

    try {
      final expenseProvider = context.read<ExpenseProvider>();
      
      if (!isAdmin) {
        // Non-admin user flow
        print('🔄 Non-admin user detected - using 2-step update');
        
        // Step 1: Update all other fields using regular updateExpense
        print('📝 Step 1: Updating expense fields...');
        
        final updatedExpense = _expense!.copyWith(
          expenseId: widget.expenseId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          amount: newAmount,
          programId: _selectedProgramId ?? _expense!.programId,
          category: _selectedCategory ?? _expense!.category,
          paymentMethod: _selectedPaymentMethod,
          expenseDate: _selectedDate,
          status: _expense!.status,
          editReason: editReason,
          isEdited: true,
          lastEditedByUserId: currentUser.uid,
          lastEditedByUserName: currentUser.displayName ?? 'User',
          lastEditedAt: Timestamp.now(),
        );
        
        await expenseProvider.updateExpense(
          updatedExpense,
          editedByUserId: currentUser.uid,
          editedByUserName: currentUser.displayName ?? 'User',
          editReason: editReason,
        );
        
        // Step 2: Update status to "pending" using updateExpenseStatus
        print('🔄 Step 2: Changing status to "pending"...');
        await expenseProvider.updateExpenseStatus(widget.expenseId, 'pending');
        
        final finalExpense = updatedExpense.copyWith(
          status: 'pending',
        );
        
        widget.onSave(finalExpense);
        
        if (!mounted) return;
        SnackbarHelper.showInfo(
          context, 
          'Expense updated. Status changed to "Pending" for admin approval.'
        );
        
      } else {
        // Admin user flow
        print('👑 Admin user - keeping current status');
        
        final updatedExpense = _expense!.copyWith(
          expenseId: widget.expenseId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          amount: newAmount,
          programId: _selectedProgramId ?? _expense!.programId,
          category: _selectedCategory ?? _expense!.category,
          paymentMethod: _selectedPaymentMethod,
          expenseDate: _selectedDate,
          status: _expense!.status,
          editReason: editReason,
          isEdited: true,
          lastEditedByUserId: currentUser.uid,
          lastEditedByUserName: currentUser.displayName ?? 'Admin',
          lastEditedAt: Timestamp.now(),
        );
        
        await expenseProvider.updateExpense(
          updatedExpense,
          editedByUserId: currentUser.uid,
          editedByUserName: currentUser.displayName ?? 'Admin',
          editReason: editReason,
        );
        
        widget.onSave(updatedExpense);
        
        if (!mounted) return;
        SnackbarHelper.showSuccess(context, 'Expense updated successfully');
      }
      
      // Navigate back
      if (mounted) Navigator.pop(context);
      
    } catch (e) {
      print('❌ Error in _saveChanges: $e');
      if (!mounted) return;
      SnackbarHelper.showError(context, 'Error updating expense: $e');
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
            ? Colors.blue.withOpacity(0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasChanged
              ? Color(Colors.blue.value).withOpacity(0.2)
              : AppColors.border(context).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    decoration: hasChanged
                        ? TextDecoration.lineThrough
                        : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
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
          
          if (hasChanged)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
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

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expense Date *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface(context),
            border: Border.all(
              color: AppColors.border(context),
            ),
          ),
          child: ListTile(
            onTap: () => _selectDate(context),
            leading: Icon(
              Icons.calendar_today,
              color: AppColors.primary(context),
              size: 20,
            ),
            title: const Text(
              'Select Date',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            subtitle: Text(
              DateFormat('MMM dd, yyyy').format(_selectedDate),
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.arrow_drop_down,
              color: AppColors.textSecondary(context),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: const Text(
          'Edit Expense',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.background(context),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(context),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        automaticallyImplyLeading: true,
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                            'Error loading expense',
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
                            onPressed: _fetchExpenseAndPrograms,
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
                          // Expense ID info

                         
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Program Selection Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Program *',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedProgramId,
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
                                      items: _availablePrograms.map((program) {
                                        return DropdownMenuItem<String>(
                                          value: program.programId,
                                          child: Text(
                                            program.title,
                                            style: TextStyle(
                                              color: AppColors.textPrimary(context),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() => _selectedProgramId = value);
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a program';
                                        }
                                        return null;
                                      },
                                      hint: const Text('Select Program'),
                                    ),
                                    if (_availablePrograms.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'No active programs found in this community',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange[700],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Title Field
                                _buildInputField(
                                  controller: _titleController,
                                  label: 'Expense Title',
                                  icon: Icons.title,
                                  hint: 'Enter expense title',
                                  maxLength: 50,
                                  showCharacterCounter: true,
                                  isRequired: true,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter expense title';
                                    }
                                    final alphabetCount = value.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
                                    if (alphabetCount < 3) {
                                      return 'Title must have at least 3 alphabet characters';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),

                                // Description Field
                                _buildInputField(
                                  controller: _descriptionController,
                                  label: 'Description',
                                  icon: Icons.description,
                                  hint: 'Add expense details...',
                                  maxLines: 3,
                                  maxLength: 200,
                                ),

                                const SizedBox(height: 16),

                                // Amount Field
                                _buildInputField(
                                  controller: _amountController,
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

                                // Category Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Category *',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedCategory,
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
                                      items: _categories.map((category) {
                                        return DropdownMenuItem<String>(
                                          value: category,
                                          child: Text(
                                            _formatCategory(category),
                                            style: TextStyle(
                                              color: AppColors.textPrimary(context),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() => _selectedCategory = value);
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select category';
                                        }
                                        return null;
                                      },
                                      hint: const Text('Select Category'),
                                    ),
                                  ],
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
                                      value: _selectedPaymentMethod,
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
                                            _formatPaymentMethod(method),
                                            style: TextStyle(
                                              color: AppColors.textPrimary(context),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() => _selectedPaymentMethod = value);
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

                                // Date Selection
                                _buildDatePickerField(),

                                const SizedBox(height: 16),

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
                            color: AppColors.surface(context),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.12),
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
                                  
                                  Container(
                                    height: 1,
                                    color: AppColors.border(context).withOpacity(0.5),
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  Column(
                                    children: [
                                      _buildChangeItem(
                                        label: 'Amount',
                                        oldValue: '₹${_expense!.amount.toStringAsFixed(2)}',
                                        newValue: '₹${_amountController.text.isNotEmpty ? _amountController.text : "0.00"}',
                                        hasChanged: '₹${_expense!.amount.toStringAsFixed(2)}' != '₹${_amountController.text.isNotEmpty ? _amountController.text : "0.00"}',
                                      ),
                                      
                                      const SizedBox(height: 8),

                                      _buildChangeItem(
                                        label: 'Title',
                                        oldValue: _expense!.title,
                                        newValue: _titleController.text.trim(),
                                        hasChanged: _expense!.title != _titleController.text.trim(),
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      
                                      _buildChangeItem(
                                        label: 'Program',
                                        oldValue: _getProgramNameById(_expense!.programId),
                                        newValue: _selectedProgramId != null
                                            ? _getProgramNameById(_selectedProgramId!)
                                            : _getProgramNameById(_expense!.programId),
                                        hasChanged: _expense!.programId != _selectedProgramId,
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      
                                      _buildChangeItem(
                                        label: 'Category',
                                        oldValue: _formatCategory(_expense!.category),
                                        newValue: _selectedCategory != null 
                                            ? _formatCategory(_selectedCategory!)
                                            : _formatCategory(_expense!.category),
                                        hasChanged: _expense!.category != _selectedCategory,
                                      ),
                                      
                                      if (_descriptionController.text.trim() != _expense!.description) ...[
                                        const SizedBox(height: 8),
                                        _buildChangeItem(
                                          label: 'Description',
                                          oldValue: _expense!.description,
                                          newValue: _descriptionController.text.trim(),
                                          hasChanged: true,
                                        ),
                                      ],
                                      
                                      if (_selectedPaymentMethod != _expense!.paymentMethod) ...[
                                        const SizedBox(height: 8),
                                        _buildChangeItem(
                                          label: 'Payment Method',
                                          oldValue: _expense!.paymentMethod != null
                                              ? _formatPaymentMethod(_expense!.paymentMethod!)
                                              : 'Not set',
                                          newValue: _selectedPaymentMethod != null
                                              ? _formatPaymentMethod(_selectedPaymentMethod!)
                                              : 'Not set',
                                          hasChanged: true,
                                        ),
                                      ],
                                      
                                      if (_selectedDate != _expense!.expenseDate) ...[
                                        const SizedBox(height: 8),
                                        _buildChangeItem(
                                          label: 'Date',
                                          oldValue: DateFormat('MMM dd, yyyy').format(_expense!.expenseDate),
                                          newValue: DateFormat('MMM dd, yyyy').format(_selectedDate),
                                          hasChanged: true,
                                        ),
                                      ],
                                    ],
                                  ),
                                  
                                  if (!_hasAnyChanges)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.grey.withOpacity(0.2),
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