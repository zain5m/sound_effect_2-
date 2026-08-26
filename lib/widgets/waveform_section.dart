import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sound_effect_2/ads/ads_provider.dart';
import 'package:sound_effect_2/models/audio_segment.dart';
import 'package:sound_effect_2/models/pcm_audio_buffer.dart';

import '../providers/audio_app_provider.dart';
import '../theme/app_theme.dart';
import 'waveform_painter.dart';

class WaveformSection extends StatefulWidget {
  const WaveformSection({super.key});

  @override
  State<WaveformSection> createState() => _WaveformSectionState();
}

class _WaveformSectionState extends State<WaveformSection> {
  final GlobalKey _waveformKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AudioAppProvider>();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(22),
      decoration: AppDecorations.softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Selector<AudioAppProvider, String>(
            selector: (_, p) => p.fileDisplayName,
            builder: (context, fileName, _) {
              return Text(
                fileName,
                style: GoogleFonts.tajawal(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'الموجة الصوتية — الخطوط الحمراء = فترات الصمت',
            style: GoogleFonts.tajawal(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            key: _waveformKey,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.6),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                Selector<
                  AudioAppProvider,
                  ({
                    PcmAudioBuffer buffer,
                    double threshold,
                    List<SilenceRange> silenceRanges,
                    List<SegmentRange> segmentRanges,
                    bool showSegments,
                  })
                >(
                  selector: (context, provider) => (
                    buffer: provider.audioBuffer!,
                    threshold: provider.splitSettings.threshold,
                    silenceRanges: provider.silenceRanges,
                    segmentRanges: provider.segmentRanges,
                    showSegments: provider.segments.isNotEmpty,
                  ),
                  builder: (context, value, child) {
                    return CustomPaint(
                      painter: WaveformPainter(
                        buffer: value.buffer,
                        threshold: value.threshold,
                        silenceRanges: value.silenceRanges,
                        segmentRanges: value.segmentRanges,
                        showSegments: value.showSegments,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Selector<AudioAppProvider, double>(
              selector: (context, provider) => provider.audioBuffer!.duration,
              builder: (context, duration, child) {
                final mid = duration / 2;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0:00', style: _timeStyle()),
                    Text(formatTime(mid), style: _timeStyle()),
                    Text(formatTime(duration), style: _timeStyle()),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Legend(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              PillActionButton(
                label: 'اكتشاف الصمت وتقسيم',
                background: AppColors.primaryLight,
                foreground: AppColors.primaryDark,
                onPressed: provider.analyzeAndSplit,
              ),
              Selector<AudioAppProvider, bool>(
                selector: (context, provider) => provider.segments.isNotEmpty,
                builder: (context, isSegments, child) {
                  return isSegments
                      ? PillActionButton(
                          label: 'تحميل الكل (ZIP)',
                          background: AppColors.accentLight,
                          foreground: AppColors.success,
                          onPressed: () async {
                            final shown = await context
                                .read<AdsProvider>()
                                .rewardedController
                                .show(
                                  onRewarded: () {
                                    provider.downloadAll();
                                  },
                                );

                            if (!shown) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('الإعلان غير جاهز بعد'),
                                ),
                              );
                            }
                          },
                        )
                      : SizedBox.shrink();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _timeStyle() =>
      GoogleFonts.tajawal(color: AppColors.textSecondary, fontSize: 12);
}

class Legend extends StatelessWidget {
  const Legend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: const [
        LegendChip(
          color: AppColors.chipBlue,
          dotColor: AppColors.waveformStart,
          label: 'صوت نشط (مقطع)',
        ),
        LegendChip(
          color: AppColors.chipPurple,
          dotColor: AppColors.waveformSilence,
          label: 'خط صامت (فاصل)',
        ),
        LegendChip(
          color: AppColors.chipGreen,
          dotColor: AppColors.waveformCursor,
          label: 'حد الصمت',
        ),
      ],
    );
  }
}

class LegendChip extends StatelessWidget {
  const LegendChip({
    super.key,
    required this.color,
    required this.dotColor,
    required this.label,
  });

  final Color color;
  final Color dotColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.tajawal(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class PillActionButton extends StatelessWidget {
  const PillActionButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: AppDecorations.pillButton(background),
          child: Text(
            label,
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
