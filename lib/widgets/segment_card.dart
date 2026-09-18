import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sound_effect_2/models/pcm_audio_buffer.dart';

import '../providers/audio_app_provider.dart';
import '../theme/app_theme.dart';
import 'rewarded_download_dialog.dart';
import 'waveform_painter.dart';

class SegmentCard extends StatelessWidget {
  const SegmentCard({super.key, required this.index});
  final int index;

  Color get _cardColor =>
      index.isEven ? AppColors.primaryLight : AppColors.secondaryLight;

  Color get _accentColor =>
      index.isEven ? AppColors.primaryDark : AppColors.secondaryDark;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AudioAppProvider>();

    return Container(
      decoration: AppDecorations.pastelPanel(_cardColor).copyWith(
        border: Border(right: BorderSide(color: _accentColor, width: 4)),
      ),
      padding: REdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30.r,
                height: 30.r,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Selector<AudioAppProvider, int>(
                  selector: (context, provider) =>
                      provider.segments[index].index,
                  builder: (context, segIndex, child) {
                    return Text(
                      '$segIndex',
                      style: GoogleFonts.tajawal(
                        color: _accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  },
                ),
              ),
              Selector<AudioAppProvider, double>(
                selector: (context, provider) =>
                    provider.segments[index].duration,
                builder: (context, segDuration, child) {
                  return Container(
                    padding: REdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      formatTime(segDuration),
                      style: GoogleFonts.tajawal(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.sp,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          RSizedBox(height: 8),
          SizedBox(
            height: 40.r,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Selector<AudioAppProvider, PcmAudioBuffer>(
                selector: (context, provider) =>
                    provider.segments[index].buffer,
                builder: (context, segBuffer, child) {
                  return CustomPaint(
                    painter: MiniWaveformPainter(
                      buffer: segBuffer,
                      colorStart: index.isEven
                          ? AppColors.waveformStart
                          : AppColors.secondary,
                      colorEnd: index.isEven
                          ? AppColors.waveformMiddle
                          : AppColors.secondaryDark,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
          RSizedBox(height: 4),
          Selector<AudioAppProvider, ({double startTime, double endTime})>(
            selector: (context, provider) => (
              startTime: provider.segments[index].startTime,
              endTime: provider.segments[index].endTime,
            ),
            builder: (context, value, child) {
              return Text(
                'من ${formatTime(value.startTime)} إلى ${formatTime(value.endTime)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  color: AppColors.textSecondary,
                  fontSize: 10.sp,
                ),
              );
            },
          ),
          RSizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SegmentPillButton(
                  label: 'تشغيل',
                  icon: Icons.play_arrow_rounded,
                  background: Colors.white.withValues(alpha: 0.75),
                  foreground: _accentColor,
                  onPressed: () => provider.playSegment(index),
                ),
              ),
              RSizedBox(width: 8),
              Expanded(
                child: _SegmentPillButton(
                  label: 'تحميل',
                  icon: Icons.download_rounded,
                  background: AppColors.accentLight,
                  foreground: AppColors.success,
                  onPressed: () => showRewardedDownloadDialog(
                    context,
                    onRewarded: () => provider.downloadSegment(index),
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

class _SegmentPillButton extends StatelessWidget {
  const _SegmentPillButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Ink(
          padding: REdgeInsets.symmetric(vertical: 8),
          decoration: AppDecorations.pillButton(background),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              RSizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.tajawal(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SegmentsSection extends StatelessWidget {
  const SegmentsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AudioAppProvider, bool>(
      selector: (context, provider) => provider.segments.isEmpty,
      builder: (context, isSegments, child) {
        if (isSegments) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المقاطع المقطوعة',
                  style: GoogleFonts.tajawal(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: REdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: AppDecorations.pillButton(AppColors.accentLight),
                  child: Selector<AudioAppProvider, int>(
                    selector: (context, provider) => provider.segments.length,
                    builder: (context, segmentsLength, child) {
                      return Text(
                        '$segmentsLength مقطع',
                        style: GoogleFonts.tajawal(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.sp,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            RSizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
                return Selector<AudioAppProvider, int>(
                  selector: (context, provider) => provider.segments.length,
                  builder: (context, segmentsLength, child) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: crossAxisCount == 1 ? 1.8 : 1.2,
                      ),
                      itemCount: segmentsLength,
                      itemBuilder: (context, index) =>
                          SegmentCard(index: index),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
