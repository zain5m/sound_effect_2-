import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/audio_app_provider.dart';
import '../theme/app_theme.dart';

class MasterEffectsPanel extends StatelessWidget {
  const MasterEffectsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AudioAppProvider>();
    return PanelCard(
      icon: Icons.equalizer_rounded,
      title: 'التأثيرات الرئيسية',
      subtitle: 'تطبق على جميع المقاطع والتصدير',
      backgroundColor: AppColors.secondaryLight,
      iconBackground: AppColors.chipPurple,
      onReset: () => provider.resetMasterSettings(),
      child: Column(
        spacing: 20.h,
        children: [
          Selector<
            AudioAppProvider,
            ({double speed, int? originalBpm, int? currentBpm})
          >(
            selector: (context, provider) => (
              speed: provider.editingSettings.speed,
              originalBpm: provider.originalBpm,
              currentBpm: provider.currentBpm,
            ),
            builder: (context, values, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8.h,
                children: [
                  SliderRow(
                    icon: Icons.speed,
                    label: 'سرعة التشغيل (Time-Stretch)',
                    value: values.speed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 150,
                    displayValue: '${values.speed.toStringAsFixed(2)}x',
                    onChanged: provider.setSpeed,
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text(
                        'الإيقاع الأصلي: ${values.originalBpm ?? '--'} BPM',
                        style: GoogleFonts.tajawal(
                          fontSize: 11.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'الإيقاع الحالي: ${values.currentBpm ?? '--'} BPM',
                        style: GoogleFonts.tajawal(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          Selector<AudioAppProvider, int>(
            selector: (context, provider) => provider.editingSettings.pitch,
            builder: (context, pitch, _) {
              final pitchSign = pitch > 0 ? '+' : '';
              return SliderRow(
                icon: Icons.tune,
                label: 'تغيير النغمة (Pitch-Shift)',
                value: pitch.toDouble(),
                min: -12,
                max: 12,
                divisions: 24,
                displayValue: '$pitchSign$pitch سنت',
                onChanged: (v) => provider.setPitch(v.round()),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // GradientButton(
              //   label: 'تطبيق التأثيرات',
              //   colors: const [AppColors.secondary, AppColors.secondaryDark],
              //   onPressed: provider.applyEffects,
              // ),
              GradientButton(
                label: 'تشغيل الملف كاملاً',
                colors: const [AppColors.primary, AppColors.primaryDark],
                onPressed: provider.playMaster,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SplitSettingsPanel extends StatelessWidget {
  const SplitSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AudioAppProvider>();

    return PanelCard(
      icon: Icons.settings_input_component_rounded,
      title: 'إعدادات التقسيم',
      subtitle: 'التحكم في طريقة اكتشاف الصمت وتقسيم الملف',
      backgroundColor: AppColors.primaryLight,
      iconBackground: AppColors.chipBlue,
      onReset: () => provider.resetSplitSettings(),
      child: Column(
        spacing: 20.h,
        children: [
          Selector<AudioAppProvider, double>(
            selector: (context, provider) => provider.splitSettings.threshold,
            builder: (context, threshold, _) {
              return SliderRow(
                icon: Icons.graphic_eq,
                label: 'حد الصمت المطلق (أقل من هذه القيمة = خط مسطح)',
                value: threshold,
                min: 0,
                max: 0.05,
                divisions: 100,
                displayValue: threshold.toString(),
                onChanged: provider.setThreshold,
              );
            },
          ),
          Selector<AudioAppProvider, double>(
            selector: (context, provider) => provider.splitSettings.minSilence,
            builder: (context, minSilence, _) {
              return SliderRow(
                icon: Icons.timer,
                label: 'أدنى مدة صمت (ثانية)',
                value: minSilence,
                min: 0.05,
                max: 5,
                divisions: 99,
                displayValue: '$minSilence ثانية',
                onChanged: provider.setMinSilence,
              );
            },
          ),
          Selector<AudioAppProvider, double>(
            selector: (context, provider) => provider.splitSettings.windowMs,
            builder: (context, windowMs, _) {
              return SliderRow(
                icon: Icons.grid_view,
                label: 'حجم نافذة التحليل (مللي ثانية)',
                value: windowMs,
                min: 5,
                max: 100,
                divisions: 19,
                displayValue: '${windowMs.toInt()} مللي ثانية',
                onChanged: provider.setWindowMs,
              );
            },
          ),
        ],
      ),
    );
  }
}

class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.title,
    this.subtitle,
    this.onReset,
    required this.icon,
    required this.child,
    this.backgroundColor = AppColors.bgCard,
    this.iconBackground = AppColors.primaryLight,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onReset;
  final Widget child;
  final Color backgroundColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: REdgeInsets.symmetric(vertical: 10),
      padding: REdgeInsets.all(22),
      decoration: AppDecorations.pastelPanel(backgroundColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 28),
              ),
              RSizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.tajawal(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle!,
                          style: GoogleFonts.tajawal(
                            fontSize: 10.sp,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onReset != null)
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('افتراضي'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
    required this.icon,
  });

  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.tajawal(
                  color: AppColors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        Text(
          displayValue,
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryDark,
          ),
        ),
      ],
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.colors = const [AppColors.primary, AppColors.primaryDark],
  });

  final String label;
  final VoidCallback onPressed;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Padding(
            padding: REdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              label,
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
