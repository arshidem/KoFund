import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/features/auth/providers/app_auth_provider.dart';
import 'package:kofund/features/virtual_users/providers/virtual_user_provider.dart';
import 'package:kofund/core/constants/app_dimensions.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

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

  @override
  void initState() {
    super.initState();
    _users.add({'name': '', 'phone': '', 'email': ''});

    _bulkFocus.addListener(() {
      if (!_showBulkInput) return; // ignore focus when bulk is closed
      setState(() {});
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
    final _authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final currentUser = _authProvider.user;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final adminName = currentUser.displayName ?? currentUser.email.split('@').first;

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
                )),
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
                  )),
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

    return GradientSheetScaffold(
      title: 'Virtual Members',
      headerHeight: 60,
      body: Column(
        children: [
          // Summary & Controls Header
          _buildActionHeader(),
          
          const Divider(height: 1, thickness: 1),
          
          // Main content area
          Expanded(
            child: Stack(
              children: [
                // Scrollable content
                _buildMainContent(isLoading),
                
                // Loading Overlay
                if (isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary(context)),
                            const SizedBox(height: 16),
                            Text(
                              'Creating members...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Fixed Bottom Action Bar
          if (!_showBulkInput) _buildPremiumBottomBar(isLoading),
        ],
      ),
    );
  }

  Widget _buildActionHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.background(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batch Registration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      widget.communityName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildBulkToggle(),
            ],
          ),
          if (!_showBulkInput) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatBadge(
                  'Total Items', 
                  '${_users.length}', 
                  Icons.format_list_numbered_rounded,
                  AppColors.primary(context),
                ),
                const SizedBox(width: 12),
                _buildStatBadge(
                  'Valid Leads', 
                  '${_users.where((u) => (u['name'] as String).trim().isNotEmpty).length}', 
                  Icons.check_circle_rounded,
                  Colors.green,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkToggle() {
    return Material(
      color: _showBulkInput 
          ? AppColors.primary(context) 
          : AppColors.primary(context).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: InkWell(
        onTap: _toggleBulkInput,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showBulkInput ? Icons.edit_note_rounded : Icons.upload_file_rounded,
                size: 18,
                color: _showBulkInput ? Colors.white : AppColors.primary(context),
              ),
              const SizedBox(width: 8),
              Text(
                _showBulkInput ? 'Manual Entry' : 'Bulk Import',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _showBulkInput ? Colors.white : AppColors.primary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isLoading) {
    if (_showBulkInput) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBulkTutorial(),
            const SizedBox(height: 20),
            _buildEnhancedBulkInput(),
            const SizedBox(height: 24),
            _buildBulkActionButtons(isLoading),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: _users.length + 1, // Added 1 for the "Add Another" button
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            child: OutlinedButton.icon(
              onPressed: _addNewUser,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Another Member'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: AppColors.primary(context), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          );
        }
        return _buildPremiumUserCard(index, _users[index]);
      },
    );
  }

  Widget _buildBulkTutorial() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'How to Import',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste your member list separated by lines. You can include phone and email separated by commas.',
            style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Format: Name, Phone, Email',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedBulkInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'RAW DATA INPUT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.textTertiary(context),
                letterSpacing: 1.5,
              ),
            ),
          ),
          TextField(
            focusNode: _bulkFocus,
            controller: _bulkInputController,
            maxLines: 12,
            minLines: 8,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              hintText: 'John Doe, 9876543210, john@example.com\nJane Smith, 9988776655\nMike Ross',
              hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionButtons(bool isLoading) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _importFromBulkInput,
            icon: const Icon(Icons.flash_on_rounded, size: 18),
            label: const Text('Process & Import'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumUserCard(int index, Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.border(context).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: AppColors.primary(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'MEMBER DETAILS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textTertiary(context),
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                if (_users.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.red.withValues(alpha: 0.7), size: 22),
                    onPressed: () => _removeUser(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                _buildModernTextField(
                  initialValue: user['name'] as String,
                  label: 'Full Name',
                  hint: 'Enter member name',
                  icon: Icons.person_rounded,
                  isRequired: true,
                  onChanged: (val) => _updateUserField(index, 'name', val),
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernTextField(
                        initialValue: user['phone'] as String? ?? '',
                        label: 'Phone Number',
                        hint: '9876543210',
                        icon: Icons.phone_android_rounded,
                        onChanged: (val) => _updateUserField(index, 'phone', val),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  initialValue: user['email'] as String? ?? '',
                  label: 'Email Address',
                  hint: 'member@example.com',
                  icon: Icons.alternate_email_rounded,
                  onChanged: (val) => _updateUserField(index, 'email', val),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required String initialValue,
    required String label,
    required String hint,
    required IconData icon,
    required void Function(String) onChanged,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: RichText(
            text: TextSpan(
              text: label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
              ),
              children: isRequired ? [
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                )
              ] : [],
            ),
          ),
        ),
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textTertiary(context).withValues(alpha: 0.5),
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(icon, size: 18, color: AppColors.primary(context)),
            filled: true,
            fillColor: AppColors.surface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.border(context).withValues(alpha: 0.6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primary(context), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumBottomBar(bool isLoading) {
    final validCount = _users.where((u) => (u['name'] as String).trim().isNotEmpty).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ready to register',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary(context),
                      ),
                    ),
                    Text(
                      '$validCount Member${validCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: validCount > 0 ? AppColors.primary(context) : AppColors.textTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: validCount > 0 && !isLoading ? _createVirtualUsers : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                      elevation: validCount > 0 ? 8 : 0,
                      shadowColor: AppColors.primary(context).withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.how_to_reg_rounded),
                              SizedBox(width: 10),
                              Text(
                                'Complete Setup',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}





