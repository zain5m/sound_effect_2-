import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/audio_app_provider.dart';
import '../theme/app_theme.dart';

class PlayerBottomBar extends StatelessWidget {
  const PlayerBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AudioAppProvider>();

    return Selector<AudioAppProvider, bool>(
      selector: (context, provider) => provider.audioBuffer != null,
      builder: (context, isLoadingFile, child) {
        if (!isLoadingFile) return const SizedBox.shrink();

        return Material(
          color: Colors.white.withValues(alpha: 0.97),
          elevation: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: AppDecorations.topShadow),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Selector<AudioAppProvider, double>(
                    selector: (_, provider) => provider.playbackProgress,
                    builder: (context, progress, _) {
                      return SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: AppColors.playButton,
                          inactiveTrackColor: AppColors.sliderInactive,
                          thumbColor: AppColors.playButton,
                          overlayColor: AppColors.playButton.withValues(
                            alpha: 0.15,
                          ),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (value) {
                            context
                                .read<AudioAppProvider>()
                                .updateDraggingProgress(value);
                          },
                          onChangeEnd: (value) {
                            context.read<AudioAppProvider>().seekTo(value);
                          },
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: REdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Row(
                      children: [
                        _PlaybackTime(),
                        const Spacer(),
                        IconButton(
                          onPressed: provider.prevSegment,
                          icon: const Icon(Icons.skip_next_rounded),
                          color: AppColors.textSecondary,
                        ),
                        RSizedBox(width: 4),
                        Selector<AudioAppProvider, bool>(
                          selector: (context, provider) =>
                              provider.playback.isPlaying,
                          builder: (context, isPlaying, child) {
                            return Material(
                              color: AppColors.playButton,
                              shape: const CircleBorder(),
                              elevation: 4,
                              shadowColor: AppColors.playButton.withValues(
                                alpha: 0.4,
                              ),
                              child: InkWell(
                                onTap: provider.togglePlayback,
                                customBorder: const CircleBorder(),
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        RSizedBox(width: 4),
                        IconButton(
                          onPressed: provider.nextSegment,
                          icon: const Icon(Icons.skip_previous_rounded),
                          color: AppColors.textSecondary,
                        ),
                        const Spacer(),
                        Selector<AudioAppProvider, String>(
                          selector: (context, provider) =>
                              provider.playerSegmentName,
                          builder: (context, value, child) {
                            return RSizedBox(
                              width: 80,
                              child: Text(
                                value,
                                textAlign: TextAlign.end,
                                style: GoogleFonts.tajawal(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.sp,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaybackTime extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<AudioAppProvider, ({Duration position, Duration duration})>(
      selector: (_, provider) => (
        position: provider.displayPosition,
        duration: provider.displayDuration,
      ),
      builder: (context, value, child) {
        final durSafe = value.duration.inSeconds > 0
            ? value.duration.inSeconds
            : 1;

        return RSizedBox(
          width: 90,
          child: Text(
            '${formatTime(value.position.inSeconds.toDouble())} / '
            '${formatTime(durSafe.toDouble())}',
            style: GoogleFonts.tajawal(
              color: AppColors.textSecondary,
              fontSize: 11.sp,
            ),
          ),
        );
      },
    );
  }
}
