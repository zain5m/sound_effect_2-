import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/audio_app_provider.dart';
import '../theme/app_theme.dart';

class UploadArea extends StatelessWidget {
  const UploadArea({super.key});

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _pickFile(context),
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Ink(
                width: double.infinity,
                decoration: AppDecorations.pastelPanel(AppColors.primaryLight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 50,
                    horizontal: 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          size: 36,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'انقر لاختيار الملف الصوتي',
                        style: GoogleFonts.tajawal(
                          fontSize: 20,
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
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Ink(
          decoration: AppDecorations.softCard(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.audio_file_rounded,
                    color: AppColors.primaryDark,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الملف الحالي',
                        style: GoogleFonts.tajawal(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          fontSize: 17,
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
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: AppDecorations.pillButton(AppColors.accentLight),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.swap_horiz_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 6),
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
