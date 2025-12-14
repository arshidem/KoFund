// lib/features/contributions/screens/update_contribution_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/contribution_provider.dart';
import '../models/contribution_model.dart';

class UpdateContributionScreen extends StatefulWidget {
  final ContributionModel contribution;

  const UpdateContributionScreen({super.key, required this.contribution});

  @override
  State<UpdateContributionScreen> createState() => _UpdateContributionScreenState();
}

class _UpdateContributionScreenState extends State<UpdateContributionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _selectedPaymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    _amountController.text = widget.contribution.amount.toString();
    _selectedPaymentMethod = widget.contribution.paymentMethod;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _updateContribution() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ContributionProvider>();
    
    // Use copyWith from ContributionModel
    final updatedContribution = widget.contribution.copyWith(
      amount: double.parse(_amountController.text),
      paymentMethod: _selectedPaymentMethod,
      // Keep monthly fields unchanged
      isMonthlyContribution: widget.contribution.isMonthlyContribution,
      monthId: widget.contribution.monthId,
    );

    try {
      await provider.updateContribution(updatedContribution);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contribution updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating contribution: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Contribution'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _updateContribution,
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Current Contribution Details
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Current Details',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Program ID:', widget.contribution.programId),
                      _buildDetailRow('User ID:', widget.contribution.userId),
                      _buildDetailRow('Original Amount:', '₹${widget.contribution.amount}'),
                      _buildDetailRow('Payment Method:', widget.contribution.paymentMethod),
                      _buildDetailRow('Status:', 'Completed', isCompleted: true),
                      _buildDetailRow('Created:', _formatDate(widget.contribution.createdAt)),
                      
                      // ✅ FIXED: Show monthly contribution info if applicable
                      if (widget.contribution.isMonthlyContribution && widget.contribution.monthId != null) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        _buildDetailRow('Type:', 'Monthly Contribution', isCompleted: true),
                        _buildDetailRow('Month:', widget.contribution.monthId!, isCompleted: true),
                      ] else if (widget.contribution.isMonthlyContribution) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        _buildDetailRow('Type:', 'Monthly Contribution', isCompleted: true),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Amount Field
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  hintText: 'Enter contribution amount',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Payment Method Dropdown
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                ],
                onChanged: (value) {
                  setState(() => _selectedPaymentMethod = value!);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select payment method';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Status Display (Read-only)
              TextFormField(
                initialValue: 'Completed',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.check_circle, color: Colors.green),
                ),
              ),
              const SizedBox(height: 24),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _updateContribution,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Update Contribution',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              // Info Card
              const SizedBox(height: 16),
              Card(
                color: Colors.green[50],
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All contributions are automatically marked as completed',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
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
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isCompleted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isCompleted ? Colors.green : Colors.black,
                fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}