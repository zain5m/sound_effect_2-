import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/audio_app_provider.dart';
import '../theme/app_theme.dart';

class ActionsSheet extends StatelessWidget {
  const ActionsSheet({super.key, this.onScrollToEffects, this.onScrollToSplit});

  final VoidCallback? onScrollToEffects;
  final VoidCallback? onScrollToSplit;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onScrollToEffects,
    VoidCallback? onScrollToSplit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ActionsSheet(
        onScrollToEffects: onScrollToEffects,
        onScrollToSplit: onScrollToSplit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AudioAppProvider>();
    final hasFile = provider.audioBuffer != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: AppDecorations.softCard(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _ActionTile(
            icon: Icons.content_cut_rounded,
            label: 'قص / تقسيم',
            background: AppColors.chipBlue,
            iconColor: AppColors.primaryDark,
            enabled: hasFile,
            onTap: () {
              Navigator.pop(context);
              provider.analyzeAndSplit();
            },
          ),
          _ActionTile(
            icon: Icons.speed_rounded,
            label: 'تعديل السرعة',
            background: AppColors.chipGreen,
            iconColor: AppColors.success,
            enabled: hasFile,
            onTap: () {
              Navigator.pop(context);
              onScrollToEffects?.call();
            },
          ),
          _ActionTile(
            icon: Icons.equalizer_rounded,
            label: 'التأثيرات',
            background: AppColors.chipPurple,
            iconColor: AppColors.secondaryDark,
            enabled: hasFile,
            onTap: () {
              Navigator.pop(context);
              onScrollToEffects?.call();
            },
          ),
          _ActionTile(
            icon: Icons.tune_rounded,
            label: 'إعدادات التقسيم',
            background: AppColors.chipBlue,
            iconColor: AppColors.primaryDark,
            enabled: hasFile,
            onTap: () {
              Navigator.pop(context);
              onScrollToSplit?.call();
            },
          ),
          _ActionTile(
            icon: Icons.file_download_rounded,
            label: 'تصدير الكل',
            background: AppColors.chipGreen,
            iconColor: AppColors.success,
            enabled: hasFile && provider.segments.isNotEmpty,
            onTap: () {
              Navigator.pop(context);
              provider.downloadAll();
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.background,
    required this.iconColor,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: enabled ? background : AppColors.divider,
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: enabled ? iconColor : AppColors.textHint,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: enabled ? AppColors.textSecondary : AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
