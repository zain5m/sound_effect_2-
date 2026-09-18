import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ads/ads_provider.dart';
import '../theme/app_theme.dart';

Future<void> showRewardedDownloadDialog(
  BuildContext context, {
  required VoidCallback onRewarded,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        scrollable: true,
        title: const Text('التحميل بعد مشاهدة إعلان'),
        content: const Text(
          'لتتمكن من التحميل، يجب عليك مشاهدة فيديو إعلاني. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إغلاق'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('موافقة'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final shown = await context.read<AdsProvider>().rewardedController.show(
    onRewarded: onRewarded,
  );

  if (!shown && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('الإعلان غير جاهز بعد')));
  }
}
