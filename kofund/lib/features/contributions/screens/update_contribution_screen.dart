// // lib/features/contributions/screens/update_contribution_screen.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import '../providers/contribution_provider.dart';
// import '../models/contribution_model.dart';
// import 'package:kofund/features/history/widgets/custom_text_field.dart';

// class UpdateContributionScreen extends StatefulWidget {
//   final ContributionModel contribution;

//   const UpdateContributionScreen({super.key, required this.contribution});

//   @override
//   State<UpdateContributionScreen> createState() => _UpdateContributionScreenState();
// }

// class _UpdateContributionScreenState extends State<UpdateContributionScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _amountController = TextEditingController();
//   final _editReasonController = TextEditingController();
//   final _noteController = TextEditingController();
  
//   String _selectedPaymentMethod = 'cash';
//   bool _isMonthly = false;
//   String? _selectedMonthId;
  
//   // Available months for selection
//   final List<String> _availableMonths = [];
//   final List<String> _paymentMethods = [
//     'Cash',
//     'UPI',
//     'Bank Transfer',
//     'Cheque',
//     'Credit Card',
//     'Debit Card',
//     'Other',
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _initializeForm();
//     _generateAvailableMonths();
//   }

//   void _initializeForm() {
//     _amountController.text = widget.contribution.amount.toStringAsFixed(2);
//     _selectedPaymentMethod = widget.contribution.paymentMethod;
//     _noteController.text = widget.contribution.note ?? '';
//     _isMonthly = widget.contribution.isMonthlyContribution;
//     _selectedMonthId = widget.contribution.monthId;
//   }

//   void _generateAvailableMonths() {
//     final now = DateTime.now();
//     // Generate 12 months (current + past 11)
//     for (int i = 0; i < 12; i++) {
//       final date = DateTime(now.year, now.month - i, 1);
//       final monthId = '${date.year}-${date.month.toString().padLeft(2, '0')}';
//       final monthName = DateFormat('MMM yyyy').format(date);
//       _availableMonths.add(monthId);
//     }
//   }

//   String _formatMonthId(String monthId) {
//     try {
//       final parts = monthId.split('-');
//       if (parts.length == 2) {
//         final year = parts[0];
//         final month = int.parse(parts[1]);
//         final date = DateTime(int.parse(year), month, 1);
//         return DateFormat('MMM yyyy').format(date);
//       }
//     } catch (e) {
//       return monthId;
//     }
//     return monthId;
//   }

//   @override
//   void dispose() {
//     _amountController.dispose();
//     _editReasonController.dispose();
//     _noteController.dispose();
//     super.dispose();
//   }

//   Future<void> _updateContribution() async {
//     if (!_formKey.currentState!.validate()) return;

//     // Check if there are actual changes
//     bool hasChanges = double.parse(_amountController.text) != widget.contribution.amount ||
//         _selectedPaymentMethod != widget.contribution.paymentMethod ||
//         _noteController.text.trim() != (widget.contribution.note ?? '') ||
//         _isMonthly != widget.contribution.isMonthlyContribution ||
//         _selectedMonthId != widget.contribution.monthId;

//     if (!hasChanges) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No changes detected'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     // Show confirmation dialog if amount changed significantly
//     final newAmount = double.parse(_amountController.text);
//     if (newAmount != widget.contribution.amount) {
//       final difference = newAmount - widget.contribution.amount;
//       final confirmed = await showDialog<bool>(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('Confirm Amount Change'),
//           content: Text(
//             'You are changing the amount from ₹${widget.contribution.amount.toStringAsFixed(2)} '
//             'to ₹${newAmount.toStringAsFixed(2)} (${difference > 0 ? '+' : ''}₹${difference.abs().toStringAsFixed(2)}).\n\n'
//             'Please provide a reason for this change:',
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context, false),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => Navigator.pop(context, true),
//               child: const Text('Confirm'),
//             ),
//           ],
//         ),
//       );

//       if (confirmed != true) {
//         return;
//       }
//     }

//     final provider = context.read<ContributionProvider>();
    
//     // Get current user info
//     final authProvider = context.read<AppAuthProvider>();
//     final currentUser = authProvider.user;
    
//     // Use copyWith from ContributionModel
//     final updatedContribution = widget.contribution.copyWith(
//       amount: newAmount,
//       paymentMethod: _selectedPaymentMethod,
//       note: _noteController.text.trim(),
//       isMonthlyContribution: _isMonthly,
//       monthId: _isMonthly ? _selectedMonthId : null,
//       editReason: _editReasonController.text.trim(),
//     );

//     try {
//       await provider.updateContribution(
//         updatedContribution,
//         editedByUserId: currentUser?.uid ?? '',
//         editedByUserName: currentUser?.displayName ?? 'Admin',
//         editReason: _editReasonController.text.trim(),
//       );
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Contribution updated successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
      
//       // Navigate back
//       if (mounted) {
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error updating contribution: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Update Contribution'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.save),
//             onPressed: _updateContribution,
//             tooltip: 'Save Changes',
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // Current Contribution Details
//               Card(
//                 color: Colors.blue[50],
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Row(
//                         children: [
//                           Icon(Icons.info, color: Colors.blue, size: 20),
//                           SizedBox(width: 8),
//                           Text(
//                             'Current Details',
//                             style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 12),
//                       _buildDetailRow('Program ID:', widget.contribution.programId),
//                       _buildDetailRow('User ID:', widget.contribution.userId),
//                       _buildDetailRow('Original Amount:', '₹${widget.contribution.amount.toStringAsFixed(2)}'),
//                       _buildDetailRow('Payment Method:', widget.contribution.paymentMethod),
//                       _buildDetailRow('Status:', 'Completed', isCompleted: true),
//                       _buildDetailRow('Created:', _formatDate(widget.contribution.createdAt)),
                      
//                       if (widget.contribution.note != null && widget.contribution.note!.isNotEmpty)
//                         _buildDetailRow('Note:', widget.contribution.note!),
                      
//                       if (widget.contribution.isMonthlyContribution) ...[
//                         const SizedBox(height: 8),
//                         const Divider(),
//                         _buildDetailRow('Type:', 'Monthly Contribution', isCompleted: true),
//                         if (widget.contribution.monthId != null)
//                           _buildDetailRow('Month:', _formatMonthId(widget.contribution.monthId!), isCompleted: true),
//                       ] else {
//                         const SizedBox(height: 8),
//                         const Divider(),
//                         _buildDetailRow('Type:', 'One-time Contribution', isCompleted: true),
//                       },
                      
//                       // Show edit history if edited before
//                       if (widget.contribution.isEdited) ...[
//                         const SizedBox(height: 8),
//                         const Divider(),
//                         const Text(
//                           'Previous Edits:',
//                           style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           'Last edited by: ${widget.contribution.lastEditedByUserName ?? widget.contribution.lastEditedByUserId ?? 'Unknown'}',
//                           style: TextStyle(fontSize: 12, color: Colors.grey[700]),
//                         ),
//                         if (widget.contribution.editReason != null)
//                           Text(
//                             'Reason: ${widget.contribution.editReason}',
//                             style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
//                           ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),

//               // Amount Field
//               CurrencyTextField(
//                 label: 'Amount *',
//                 controller: _amountController,
//                 isRequired: true,
//               ),
//               const SizedBox(height: 16),

//               // Payment Method Dropdown
//               CustomDropdownField<String>(
//                 label: 'Payment Method *',
//                 value: _selectedPaymentMethod,
//                 items: _paymentMethods.map((method) {
//                   return DropdownMenuItem(
//                     value: method,
//                     child: Text(method),
//                   );
//                 }).toList(),
//                 onChanged: (value) {
//                   setState(() => _selectedPaymentMethod = value!);
//                 },
//                 isRequired: true,
//               ),
//               const SizedBox(height: 16),

//               // Monthly Contribution Toggle
//               SwitchListTile(
//                 title: const Text('Monthly Contribution'),
//                 subtitle: Text(_isMonthly
//                     ? 'This is a recurring monthly contribution'
//                     : 'This is a one-time contribution'),
//                 value: _isMonthly,
//                 onChanged: (value) {
//                   setState(() => _isMonthly = value);
//                 },
//               ),

//               // Month Selection (only for monthly)
//               if (_isMonthly) ...[
//                 const SizedBox(height: 16),
//                 CustomDropdownField<String>(
//                   label: 'Month *',
//                   value: _selectedMonthId,
//                   items: _availableMonths.map((monthId) {
//                     return DropdownMenuItem(
//                       value: monthId,
//                       child: Text(_formatMonthId(monthId)),
//                     );
//                   }).toList(),
//                   onChanged: (value) {
//                     setState(() => _selectedMonthId = value);
//                   },
//                   isRequired: true,
//                 ),
//               ],

//               const SizedBox(height: 16),

//               // Note Field
//               CustomTextField(
//                 label: 'Note (Optional)',
//                 controller: _noteController,
//                 maxLines: 3,
//                 hintText: 'Add any additional notes...',
//               ),

//               const SizedBox(height: 16),

//               // Edit Reason Field
//               CustomTextField(
//                 label: 'Reason for Edit *',
//                 controller: _editReasonController,
//                 maxLines: 2,
//                 hintText: 'Why are you making these changes?',
//                 validator: (value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return 'Please provide a reason for editing';
//                   }
//                   return null;
//                 },
//               ),

//               const SizedBox(height: 24),

//               // Changes Summary
//               Card(
//                 color: Colors.blue[50],
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Changes Summary',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.blue,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       _buildChangeItem(
//                         'Amount',
//                         '₹${widget.contribution.amount.toStringAsFixed(2)}',
//                         '₹${_amountController.text}',
//                       ),
//                       _buildChangeItem(
//                         'Payment Method',
//                         widget.contribution.paymentMethod,
//                         _selectedPaymentMethod,
//                       ),
//                       if (_noteController.text.trim() != (widget.contribution.note ?? ''))
//                         _buildChangeItem(
//                           'Note',
//                           widget.contribution.note ?? 'None',
//                           _noteController.text.trim(),
//                           isText: true,
//                         ),
//                       if (_isMonthly != widget.contribution.isMonthlyContribution)
//                         _buildChangeItem(
//                           'Type',
//                           widget.contribution.isMonthlyContribution
//                               ? 'Monthly'
//                               : 'One-time',
//                           _isMonthly ? 'Monthly' : 'One-time',
//                         ),
//                       if (_isMonthly && _selectedMonthId != widget.contribution.monthId)
//                         _buildChangeItem(
//                           'Month',
//                           widget.contribution.monthId != null
//                               ? _formatMonthId(widget.contribution.monthId!)
//                               : 'None',
//                           _selectedMonthId != null ? _formatMonthId(_selectedMonthId!) : 'None',
//                         ),
//                     ],
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 24),

//               // Update Button
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton.icon(
//                   onPressed: _updateContribution,
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                   ),
//                   icon: const Icon(Icons.save),
//                   label: const Text(
//                     'Update Contribution',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                   ),
//                 ),
//               ),

//               // Cancel Button
//               const SizedBox(height: 12),
//               SizedBox(
//                 width: double.infinity,
//                 child: OutlinedButton(
//                   onPressed: () => Navigator.pop(context),
//                   style: OutlinedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                   ),
//                   child: const Text(
//                     'Cancel',
//                     style: TextStyle(fontSize: 16),
//                   ),
//                 ),
//               ),

//               // Info Card
//               const SizedBox(height: 16),
//               Card(
//                 color: Colors.green[50],
//                 child: const Padding(
//                   padding: EdgeInsets.all(12),
//                   child: Row(
//                     children: [
//                       Icon(Icons.check_circle, color: Colors.green, size: 20),
//                       SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           'All changes are tracked in edit history for audit purposes',
//                           style: TextStyle(
//                             color: Colors.green,
//                             fontSize: 12,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildDetailRow(String label, String value, {bool isCompleted = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 2),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 120,
//             child: Text(
//               label,
//               style: TextStyle(
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey[700],
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               value,
//               style: TextStyle(
//                 color: isCompleted ? Colors.green : Colors.black,
//                 fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildChangeItem(String label, String oldValue, String newValue,
//       {bool isText = false}) {
//     final hasChanged = oldValue != newValue;
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             flex: 2,
//             child: Text(
//               '$label:',
//               style: TextStyle(
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey[700],
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 3,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   oldValue,
//                   style: TextStyle(
//                     color: hasChanged ? Colors.red : Colors.grey[600],
//                     decoration:
//                         hasChanged ? TextDecoration.lineThrough : null,
//                   ),
//                 ),
//                 if (hasChanged)
//                   Text(
//                     '→ $newValue',
//                     style: TextStyle(
//                       color: Colors.green,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatDate(Timestamp timestamp) {
//     final date = timestamp.toDate();
//     return DateFormat('dd/MM/yyyy HH:mm').format(date);
//   }
// }

// // Make sure to import your AppAuthProvider
// class AppAuthProvider {
//   final User? user;
  
//   AppAuthProvider(this.user);
// }

// class User {
//   final String? uid;
//   final String? displayName;
  
//   User({this.uid, this.displayName});
// }

// // Example of how to navigate to this screen:
// void navigateToUpdateScreen(BuildContext context, ContributionModel contribution) {
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => UpdateContributionScreen(contribution: contribution),
//     ),
//   );
// }
