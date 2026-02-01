import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/virtual_users/providers/virtual_user_provider.dart';

class CreateVirtualUsersScreen extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CreateVirtualUsersScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<CreateVirtualUsersScreen> createState() => _CreateVirtualUsersScreenState();
}

class _CreateVirtualUsersScreenState extends State<CreateVirtualUsersScreen> {
  final List<Map<String, dynamic>> _users = [];
  final TextEditingController _bulkInputController = TextEditingController();
  bool _showBulkInput = false;
  final FocusNode _bulkFocus = FocusNode();
  bool _showHeader = true;

  @override
  void initState() {
    super.initState();
    _users.add({'name': '', 'phone': '', 'email': ''});

    _bulkFocus.addListener(() {
      if (!_showBulkInput) return; // ignore focus when bulk is closed

      setState(() {
        _showHeader = !_bulkFocus.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _bulkFocus.dispose();
    _bulkInputController.dispose();
    super.dispose();
  }

  void _addNewUser() {
    setState(() {
      _users.add({'name': '', 'phone': '', 'email': ''});
    });
  }

  void _removeUser(int index) {
    if (_users.length > 1) {
      setState(() {
        _users.removeAt(index);
      });
    }
  }

  void _updateUserField(int index, String field, String value) {
    setState(() {
      _users[index][field] = value.trim();
    });
  }

  void _toggleBulkInput() {
    setState(() {
      _showBulkInput = !_showBulkInput;
    });
  }

  void _importFromBulkInput() {
    final text = _bulkInputController.text.trim();
    if (text.isEmpty) return;

    final lines = text.split('\n');
    final newUsers = <Map<String, dynamic>>[];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      final parts = trimmedLine.split(RegExp(r'[,|\t]'));
      final name = parts.isNotEmpty ? parts[0].trim() : '';
      final phone = parts.length > 1 ? parts[1].trim() : '';
      final email = parts.length > 2 ? parts[2].trim() : '';

      if (name.isNotEmpty) {
        newUsers.add({
          'name': name,
          'phone': phone,
          'email': email,
        });
      }
    }

    if (newUsers.isNotEmpty) {
      setState(() {
        _users.clear();
        _users.addAll(newUsers);
        _showBulkInput = false;
        _bulkInputController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported ${newUsers.length} users'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _createVirtualUsers() async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = authProvider.user;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final adminName = currentUser.displayName ?? 
                      currentUser.email?.split('@').first ?? 
                      'Admin';

    final validUsers = _users.where((user) {
      final name = user['name'] as String;
      return name.trim().isNotEmpty;
    }).toList();

    if (validUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one user with a name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final errors = <String>[];
    for (int i = 0; i < validUsers.length; i++) {
      final user = validUsers[i];
      final name = user['name'] as String;
      final phone = user['phone'] as String?;
      final email = user['email'] as String?;

      if (name.length < 2) {
        errors.add('User ${i + 1}: Name must be at least 2 characters');
      }

      if (phone != null && phone.isNotEmpty) {
        final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
        if (!phoneRegex.hasMatch(phone)) {
          errors.add('User ${i + 1}: Invalid phone format');
        }
      }

      if (email != null && email.isNotEmpty) {
        final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
        if (!emailRegex.hasMatch(email)) {
          errors.add('User ${i + 1}: Invalid email format');
        }
      }
    }

    if (errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Validation Errors'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please fix the following errors:'),
                const SizedBox(height: 12),
                ...errors.map((error) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('• $error'),
                )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final virtualUserProvider = Provider.of<VirtualUserProvider>(context, listen: false);
    
    await virtualUserProvider.createMultipleUsers(
      widget.communityId,
      currentUser.uid,
      adminName,
      validUsers,
    );

    if (!mounted) return;

    if (virtualUserProvider.errorMessages.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Creation Errors'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Successfully created ${virtualUserProvider.successfulCreations} users, ${virtualUserProvider.errorMessages.length} failed.'),
                if (virtualUserProvider.errorMessages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Errors:'),
                  ...virtualUserProvider.errorMessages.map((error) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('• $error'),
                  )).toList(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (virtualUserProvider.successfulCreations > 0) {
                  Navigator.pop(context, virtualUserProvider.successfulCreations);
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Successfully created ${virtualUserProvider.successfulCreations} virtual users'),
          backgroundColor: Colors.green,
        ),
      );
      
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _users.clear();
          _users.add({'name': '', 'phone': '', 'email': ''});
        });
        virtualUserProvider.resetCreationState();
        if (mounted) Navigator.of(context).pop(virtualUserProvider.successfulCreations);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final virtualUserProvider = Provider.of<VirtualUserProvider>(context);
    final isLoading = virtualUserProvider.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        toolbarHeight: 80,
        title: const Text(
          'Create Virtual Users',
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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
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
            size: 24,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showHeader ? _buildHeaderInfo() : const SizedBox.shrink(),
          ),
          const Divider(height: 1),
          if (_showBulkInput)
            _buildBulkInputSection(),
          // Scrollable content area
          Expanded(
            child: _buildScrollableContent(isLoading),
          ),
          // Fixed bottom actions
          if (!_showBulkInput) // Only show fixed bottom when NOT in bulk import
            _buildBottomActions(isLoading),
        ],
      ),
    );
  }

  Widget _buildScrollableContent(bool isLoading) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Users list when NOT in bulk import
          if (!_showBulkInput) _buildUsersList(),
          
          // When in bulk import, show bottom actions here (scrollable)
          if (_showBulkInput) 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: _buildBottomActions(isLoading),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary(context).withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.group_add, size: 20, color: AppColors.primary(context)),
                  const SizedBox(width: 8),
                  Text(
                    'Add Multiple Virtual Members',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.primary(context),
                    ),
                  ),
                ],
              ),
              // Bulk Import button in header
              ElevatedButton.icon(
                onPressed: _toggleBulkInput,
                icon: Icon(Icons.upload_file, size: 18, color: Colors.white),
                label: const Text('Bulk Import'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add members who don\'t have the app. Phone and email are optional.',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Community: ${widget.communityName}',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(
                label: Text('${_users.length} member(s)'),
                backgroundColor: Colors.white,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text('${_users.where((u) => (u['name'] as String).isNotEmpty).length} valid'),
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                labelStyle: const TextStyle(color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bulk Import',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _bulkFocus.unfocus(); // close keyboard
                  setState(() {
                    _showBulkInput = false;
                    _showHeader = true; // force header to reappear
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter one user per line. Format: Name, Phone, Email\nExample:\nJohn Doe, +919876543210, john@email.com\nJane Smith\nMike Johnson, +911234567890',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border(context)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              focusNode: _bulkFocus,
              controller: _bulkInputController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: 'Paste or type user data here...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _importFromBulkInput,
              icon: const Icon(Icons.upload_file, size: 20),
              label: const Text('Import Users'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return ListView.builder(
      shrinkWrap: true, // Important for nested ListView
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling of nested ListView
      padding: const EdgeInsets.all(16),
      itemCount: _users.length + 1,
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton.icon(
              onPressed: _addNewUser,
              icon: const Icon(Icons.add),
              label: const Text('Add Another Member'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary(context),
                side: BorderSide(color: AppColors.primary(context)),
              ),
            ),
          );
        }

        final user = _users[index];
        return _buildUserCard(index, user);
      },
    );
  }

  Widget _buildUserCard(int index, Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Member ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (_users.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeUser(index),
                    tooltip: 'Remove',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: user['name'] as String,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person),
              ),
              onChanged: (value) => _updateUserField(index, 'name', value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: user['phone'] as String? ?? '',
              decoration: const InputDecoration(
                labelText: 'Phone (Optional)',
                prefixIcon: Icon(Icons.phone),
                hintText: '+919876543210',
              ),
              keyboardType: TextInputType.phone,
              onChanged: (value) => _updateUserField(index, 'phone', value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: user['email'] as String? ?? '',
              decoration: const InputDecoration(
                labelText: 'Email (Optional)',
                prefixIcon: Icon(Icons.email),
                hintText: 'member@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => _updateUserField(index, 'email', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(bool isLoading) {
    final validCount = _users.where((u) => (u['name'] as String).isNotEmpty).length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        border: Border(
          top: _showBulkInput 
              ? BorderSide.none // No border when in bulk import (scrolling)
              : BorderSide(color: AppColors.border(context)),
        ),
        boxShadow: _showBulkInput
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to add: $validCount user(s)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: validCount > 0 ? Colors.green : Colors.grey,
                    ),
                  ),
                  if (validCount == 0)
                    const Text(
                      'Add at least one user with a name',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: validCount > 0 && !isLoading ? _createVirtualUsers : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.group_add),
                label: isLoading
                    ? const Text('Creating...')
                    : const Text('Add All Members'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Phone and email are optional. Members can be added without contact info.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
