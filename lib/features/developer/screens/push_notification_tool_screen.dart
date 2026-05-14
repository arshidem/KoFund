import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';

class PushNotificationToolScreen extends StatefulWidget {
  const PushNotificationToolScreen({super.key});

  @override
  State<PushNotificationToolScreen> createState() => _PushNotificationToolScreenState();
}

class _PushNotificationToolScreenState extends State<PushNotificationToolScreen> {
  final _fs = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  Map<String, dynamic>? _selectedUser;
  final Map<String, String> _communityNames = {};
  
  String _targetTeventType = 'Global'; // 'Global', 'Targeted', 'Community'
  Map<String, dynamic>? _selectedCommunity;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final snapshot = await _fs.collection('communities').get();
      for (var doc in snapshot.docs) {
        _communityNames[doc.id] = doc.data()['name']?.toString() ?? 'Unnnamed';
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading communities: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Push Notification Tool',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConfigurationSection(),
            const SizedBox(height: 24),
            _buildMessageSection(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isSending ? null : _confirmAndSend,
              icon: const Icon(Icons.send_to_mobile_rounded),
              label: Text(_isSending ? 'Sending...' : 'Send Push Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 20),
            _buildSafetyWarning(),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Target Audience', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary(context),
                selectedForegroundColor: Colors.white,
              ),
              segments: const [
                ButtonSegment(value: 'Global', label: Text('All'), icon: Icon(Icons.public)),
                ButtonSegment(value: 'Community', label: Text('Group'), icon: Icon(Icons.groups)),
                ButtonSegment(value: 'Targeted', label: Text('Specific'), icon: Icon(Icons.person)),
              ],
              selected: {_targetTeventType},
              onSelectionChanged: (set) => setState(() => _targetTeventType = set.first),
            ),
            const SizedBox(height: 16),
            if (_targetTeventType == 'Targeted') 
              _buildTargetUserPicker(),
            if (_targetTeventType == 'Community')
              _buildCommunityPicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetUserPicker() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option['displayName']?.toString() ?? 'Unknown User',
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        
        final queryStr = textEditingValue.text.toLowerCase();
        final snapshot = await _fs.collection('users').get();
        final matches = <Map<String, dynamic>>[];
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final name = data['displayName']?.toString().toLowerCase() ?? '';
          if (name.contains(queryStr)) {
            data['id'] = doc.id;
            matches.add(data);
          }
        }
        return matches.take(100);
      },
      onSelected: (selection) {
        setState(() => _selectedUser = selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          decoration: InputDecoration(
            labelText: 'Search Target User',
            hintText: 'type to search users...',
            prefixIcon: const Icon(Icons.person_search),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide(color: AppColors.primary(context), width: 2),
            ),
            filled: true,
            fillColor: AppColors.surface(context),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8.0,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 250,
                maxWidth: MediaQuery.of(context).size.width - 72,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: options.length,
                  shrinkWrap: true,
                  itemBuilder: (BuildContext context, int index) {
                    final option = options.elementAt(index);
                    final name = option['displayName']?.toString() ?? 'Unknown User';
                    final commId = option['communityId']?.toString();
                    final commName = _communityNames[commId] ?? 'Independent User';
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary(context).withValues(alpha: 0.2),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: AppColors.primary(context))),
                      ),
                      title: Text(name),
                      subtitle: Text(
                        commName, 
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () {
                        onSelected(option);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommunityPicker() {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option['name']?.toString() ?? 'Unnnamed Community',
      optionsBuilder: (textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Map<String, dynamic>>.empty();
        }
        
        final queryStr = textEditingValue.text.toLowerCase();
        final snapshot = await _fs.collection('communities').get();
        final matches = <Map<String, dynamic>>[];
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final name = data['name']?.toString().toLowerCase() ?? '';
          if (name.contains(queryStr)) {
            data['id'] = doc.id;
            matches.add(data);
          }
        }
        return matches.take(50);
      },
      onSelected: (selection) {
        setState(() => _selectedCommunity = selection);
      },
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          decoration: InputDecoration(
            labelText: 'Search Community',
            hintText: 'type to search communities...',
            prefixIcon: const Icon(Icons.groups),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide(color: AppColors.primary(context), width: 2),
            ),
            filled: true,
            fillColor: AppColors.surface(context),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8.0,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 250,
                maxWidth: MediaQuery.of(context).size.width - 72,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: options.length,
                  shrinkWrap: true,
                  itemBuilder: (BuildContext context, int index) {
                    final option = options.elementAt(index);
                    final name = option['name']?.toString() ?? 'Unnnamed Community';
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary(context).withValues(alpha: 0.2),
                        child: Icon(Icons.groups, color: AppColors.primary(context), size: 20),
                      ),
                      title: Text(name),
                      onTap: () {
                        onSelected(option);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('2. Message Content', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Ttitle',
                hintText: 'New Update Available',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(100),
                  borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                ),
                filled: true,
                fillColor: AppColors.surface(context),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Body',
                hintText: 'Short summary of the notification...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.primary(context), width: 2),
                ),
                filled: true,
                fillColor: AppColors.surface(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sending global notifications can disturb all users. Use only for critical announcements.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSend() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      SnackbarHelper.showError(context, 'Ttitle and Body are required');
      return;
    }

    if (_targetTeventType == 'Targeted' && _selectedUser == null) {
      SnackbarHelper.showError(context, 'Target user is required');
      return;
    }

    if (_targetTeventType == 'Community' && _selectedCommunity == null) {
      SnackbarHelper.showError(context, 'Please select a community');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Send?'),
        content: Text('Send "$_targetTeventType" notification to your audience?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Send')),
        ],
      ),
    );

    if (confirmed == true) {
      _sendNotification();
    }
  }

  Future<void> _sendNotification() async {
    setState(() => _isSending = true);
    try {
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();
      
      switch (_targetTeventType) {
        case 'Global':
          await _functions.httpsCallable('sendGlobalNotification').call({
            'title': title,
            'body': body,
          });
          break;
        case 'Targeted':
          await _functions.httpsCallable('sendTargetedNotifications').call({
            'userIds': [_selectedUser!['id']],
            'title': title,
            'body': body,
          });
          break;
        case 'Community':
          await _functions.httpsCallable('sendCommunityNotification').call({
            'communityId': _selectedCommunity!['id'],
            'title': title,
            'body': body,
            'type': 'admin_announcement',
          });
          break;
      }

      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Notification sent successfully!');
        _titleController.clear();
        _bodyController.clear();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}





