import 'package:flutter/material.dart';
import 'package:kofund/core/constants/app_colors.dart';
import 'package:kofund/core/services/app_update_service.dart';

class AppUpdateDialog extends StatelessWidget {
  final Map<String, dynamic> updateInfo;

  const AppUpdateDialog({super.key, required this.updateInfo});

  @override
  Widget build(BuildContext context) {
    final bool isForced = updateInfo['is_forced'] ?? false;
    final String version = updateInfo['latest_version'] ?? '';
    final String message = updateInfo['message'] ?? '';
    final String downloadUrl = updateInfo['download_url'] ?? '';

    return PopScope(
      canPop: !isForced,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  size: 40,
                  color: AppColors.primary(context),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Update Available',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version $version',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => AppUpdateService.openDownloadLink(downloadUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Download Update',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!isForced) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Maybe Later',
                        style: TextStyle(color: AppColors.textSecondary(context)),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Text(
                      'This update is required to continue using the app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void show(BuildContext context, Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !(updateInfo['is_forced'] ?? false),
      builder: (context) => AppUpdateDialog(updateInfo: updateInfo),
    );
  }
}





