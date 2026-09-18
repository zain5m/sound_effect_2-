import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: REdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          Text(
            'محرر الصوت الذكي',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          RSizedBox(height: 8),
          Text(
            'ارفع ملفك الصوتي، اضبط السرعة والبيتش، وسنقسمه تلقائياً',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              color: AppColors.textSecondary,
              fontSize: 15.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
