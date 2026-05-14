import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/utils/snackbar_helper.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import '../../notifications/services/announcement_service.dart';

class AnnouncementManagerScreen extends StatefulWidget {
  const AnnouncementManagerScreen({super.key});

  @override
  State<AnnouncementManagerScreen> createState() => _AnnouncementManagerScreenState();
}

class _AnnouncementManagerScreenState extends State<AnnouncementManagerScreen> {
  final _fs = FirebaseFirestore.instance;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _showOnOpen = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'Announcement Manager',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCreateCard(),
            const SizedBox(height: 32),
            Text(
              'Recent Announcements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            _buildAnnouncementsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary(context)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Ttitle',
                hintText: 'Big News!',
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
                hintText: 'Explain the announcement...',
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
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show on app open (Popup)'),
              subtitle: const Text('High priority; will block app use until dismissed'),
              value: _showOnOpen,
              activeColor: AppColors.primary(context),
              onChanged: (val) => setState(() => _showOnOpen = val),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _createAnnouncement,
                icon: const Icon(Icons.send),
                label: const Text('Publish for all users'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _fs
          .collection('announcements')
          .orderBy('created_at', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text('No announcements yet.');

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final isActive = data['is_active'] ?? true;
            
            return ListTile(
              tileColor: AppColors.card(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(data['title'] ?? ''),
              subtitle: Text(
                data['body'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Switch(
                value: isActive,
                onChanged: (val) => AnnouncementService.deactivateAnnouncement(docs[index].id),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createAnnouncement() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await AnnouncementService.createAnnouncement(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        showOnOpen: _showOnOpen,
      );
      _titleController.clear();
      _bodyController.clear();
      setState(() => _showOnOpen = false);
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Announcement published!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}





