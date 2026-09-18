import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../ads/app_open_ad_manager.dart';
import '../providers/audio_app_provider.dart';
import '../theme/app_theme.dart';

class UploadArea extends StatelessWidget {
  const UploadArea({super.key});

  Future<void> _pickFile(BuildContext context) async {
    final appOpenAdManager = context.read<AppOpenAdManager>();
    final result = await appOpenAdManager.runWithoutAppOpenAd(
      () => FilePicker.pickFiles(type: FileType.audio),
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) return;
    if (!context.mounted) return;
    await context.read<AudioAppProvider>().loadFile(
      file.path!,
      file.name,
      file.extension != null ? 'audio/${file.extension}' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AudioAppProvider, String?>(
      selector: (_, provider) =>
          provider.audioBuffer == null ? null : provider.fileDisplayName,
      builder: (context, fileDisplayName, child) {
        if (fileDisplayName != null) {
          return UploadedFileCard(
            fileName: fileDisplayName,
            onChange: () => _pickFile(context),
          );
        }
        return Padding(
          padding: REdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _pickFile(context),
              borderRadius: BorderRadius.circular(AppRadii.card.r),
              child: Ink(
                width: double.infinity,
                decoration: AppDecorations.pastelPanel(AppColors.primaryLight),
                child: Padding(
                  padding: REdgeInsets.symmetric(vertical: 50, horizontal: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72.r,
                        height: 72.r,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 36.r,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      RSizedBox(height: 18),
                      Text(
                        'انقر لاختيار الملف الصوتي',
                        style: GoogleFonts.tajawal(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'يدعم MP3, WAV, OGG, M4A, WEBM',
                        style: GoogleFonts.tajawal(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class UploadedFileCard extends StatelessWidget {
  const UploadedFileCard({
    super.key,
    required this.fileName,
    required this.onChange,
  });

  final String fileName;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChange,
        borderRadius: BorderRadius.circular(AppRadii.card.r),
        child: Ink(
          decoration: AppDecorations.softCard(),
          child: Padding(
            padding: REdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.audio_file_rounded,
                    color: AppColors.primaryDark,
                    size: 28,
                  ),
                ),
                RSizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الملف الحالي',
                        style: GoogleFonts.tajawal(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                      RSizedBox(height: 4),
                      Text(
                        fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onChange,
                    borderRadius: BorderRadius.circular(AppRadii.pill.r),
                    child: Ink(
                      padding: REdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: AppDecorations.pillButton(
                        AppColors.accentLight,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 18.r,
                            color: AppColors.success,
                          ),
                          RSizedBox(width: 6),
                          Text(
                            'تغيير',
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
