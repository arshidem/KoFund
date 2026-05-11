import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/widgets/gradient_sheet_scaffold.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kofund/core/skeleton/app_config_skeleton.dart';

class UpdateConfigScreen extends StatefulWidget {
  const UpdateConfigScreen({super.key});

  @override
  State<UpdateConfigScreen> createState() => _UpdateConfigScreenState();
}

class _UpdateConfigScreenState extends State<UpdateConfigScreen> {
  final _fs = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  
  final _latestVersionController = TextEditingController();
  final _minVersionController = TextEditingController();
  final _downloadUrlController = TextEditingController();
  final _messageController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _fetchAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _latestVersionController.text = packageInfo.version;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App version auto-filled from pubspec!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch local version: $e')),
      );
    }
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _fs.collection('app_config').doc('config').get();
      if (doc.exists) {
        final data = doc.data()!;
        _latestVersionController.text = data['latest_version'] ?? '';
        _minVersionController.text = data['min_supported_version'] ?? '';
        _downloadUrlController.text = data['download_url'] ?? '';
        _messageController.text = data['update_message'] ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading config: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _fs.collection('app_config').doc('config').set({
        'latest_version': _latestVersionController.text.trim(),
        'min_supported_version': _minVersionController.text.trim(),
        'download_url': _downloadUrlController.text.trim(),
        'update_message': _messageController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Config updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving config: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientSheetScaffold(
      title: 'App Update Config',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      body: _isLoading 
        ? const AppConfigSkeleton()
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTtitle('Version Control'),
                  _buildTextField(
                    controller: _latestVersionController,
                    label: 'Latest Version (e.g., 1.2.0)',
                    hint: 'The version currently available for download',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.sync_rounded, color: AppColors.primary(context)),
                      onPressed: _fetchAppVersion,
                      tooltip: 'Fetch from pubspec.yaml',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _minVersionController,
                    label: 'Min Supported Version (e.g., 1.1.0)',
                    hint: 'Versions older than this will be FORCED to update',
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTtitle('Download & Messaging'),
                  _buildTextField(
                    controller: _downloadUrlController,
                    label: 'Download URL (APK Link)',
                    hint: 'https://kofund.app/downloads/latest.apk',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _messageController,
                    label: 'Update Message',
                    hint: 'Explain why users should update...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isSaving 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTtitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary(context),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    final radius = maxLines > 1 ? 24.0 : 100.0;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        suffixIcon: suffixIcon,
        fillColor: AppColors.surface(context),
        isDense: maxLines == 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: AppColors.primary(context), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
    );
  }
}





