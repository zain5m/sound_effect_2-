import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // =========================
  // Brand
  // =========================

  /// Cyan المستخدم في العناصر التفاعلية
  // static const primary = Color(0xFF4FC3F7);
  static const primary = Color(0xFF4FC3F7);
  static const primaryLight = Color(0xFFE1F5FE);
  static const primaryDark = Color(0xFF29B6F6);

  /// Lavender
  static const secondary = Color(0xFFD8B8F3);
  static const secondaryLight = Color(0xFFF3E5F6);
  static const secondaryDark = Color(0xFFBA8DE8);

  /// Mint
  static const accent = Color(0xFFA5D6A7);
  static const accentLight = Color(0xFFE8F5E9);

  // =========================
  // Backgrounds
  // =========================

  static const bgPrimary = Color(0xFFF9FBFC);
  static const bgSecondary = Color(0xFFF5FAFC);
  static const bgCard = Colors.white;

  // =========================
  // Text
  // =========================

  static const textPrimary = Color(0xFF2D3436);
  static const textSecondary = Color(0xFF6C757D);
  static const textHint = Color(0xFFA3ADB5);

  // =========================
  // Borders
  // =========================

  static const border = Color(0xFFE6EEF2);
  static const divider = Color(0xFFF1F5F7);

  // =========================
  // Semantic
  // =========================

  static const success = Color(0xFF66BB6A);
  static const warning = Color(0xFFFFC107);
  static const danger = Color(0xFFEF5350);
  static const info = primaryDark;

  // =========================
  // Waveform
  // =========================

  static const waveformStart = Color(0xFF4FC3F7);
  static const waveformMiddle = Color(0xFF90CAF9);
  static const waveformEnd = Color(0xFFD8B8F3);

  static const waveformCursor = primaryDark;
  static const waveformSilence = Color(0xFFFF8A80);

  // =========================
  // Buttons
  // =========================

  static const playButton = Color(0xFF42A5F5);
  static const recordButton = Color(0xFFEF5350);
  static const fabButton = Color(0xFFE8F5E9);

  // =========================
  // Slider
  // =========================

  static const sliderActive = primary;
  static const sliderInactive = Color(0xFFD8ECF5);

  // =========================
  // Chips
  // =========================

  static const chipBlue = Color(0xFFE1F5FE);
  static const chipPurple = Color(0xFFF3E5F6);
  static const chipGreen = Color(0xFFE8F5E9);

  // =========================
  // Extra
  // =========================

  static const shadow = Color(0x11000000);
}

class AppRadii {
  static const card = 22.0;
  static const pill = 28.0;
  static const button = 18.0;
  static const small = 14.0;
}

class AppDecorations {
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get topShadow => [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 12,
      offset: const Offset(0, -2),
    ),
  ];

  static LinearGradient get headerGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.primaryLight, AppColors.bgPrimary],
  );

  static LinearGradient get waveformGradient => const LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.waveformStart,
      AppColors.waveformMiddle,
      AppColors.waveformEnd,
    ],
  );

  static BoxDecoration softCard({Color? color, Color? borderColor}) =>
      BoxDecoration(
        color: color ?? AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: softShadow,
        border: borderColor != null
            ? Border.all(color: borderColor)
            : Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      );

  static BoxDecoration pastelPanel(Color background) => BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(AppRadii.card),
    boxShadow: softShadow,
  );

  static BoxDecoration pillButton(Color background, {Color? borderColor}) =>
      BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      );
}

ThemeData buildAppTheme() {
  final textTheme = GoogleFonts.tajawalTextTheme().copyWith(
    displayLarge: const TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: const TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.bold,
    ),
    headlineLarge: const TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: const TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: const TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: const TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: const TextStyle(color: AppColors.textPrimary),
    bodyMedium: const TextStyle(color: AppColors.textPrimary),
    bodySmall: const TextStyle(color: AppColors.textSecondary),
    labelLarge: const TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: const TextStyle(color: AppColors.textSecondary),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    scaffoldBackgroundColor: AppColors.bgPrimary,

    textTheme: textTheme,

    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,

      surface: AppColors.bgCard,

      onPrimary: Colors.white,
      onSecondary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,

      error: AppColors.danger,
      onError: Colors.white,
    ),

    dividerColor: AppColors.divider,

    splashFactory: InkRipple.splashFactory,

    // ---------------- AppBar ----------------
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),

    // ---------------- Card ----------------
    cardTheme: CardThemeData(
      color: AppColors.bgCard,
      elevation: 2,
      shadowColor: AppColors.shadow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
    ),

    // ---------------- Input ----------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgSecondary,

      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),

    // ---------------- Slider ----------------
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.sliderActive,
      inactiveTrackColor: AppColors.sliderInactive,
      thumbColor: AppColors.playButton,
      overlayColor: AppColors.primary.withValues(alpha: 0.15),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),

    // ---------------- Elevated ----------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,

        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),

    // ---------------- Filled ----------------
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),

    // ---------------- Outlined ----------------
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,

        side: const BorderSide(color: AppColors.primary),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),

    // ---------------- FAB ----------------
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.fabButton,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      shape: CircleBorder(),
    ),

    // ---------------- Chip ----------------
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.chipBlue,

      selectedColor: AppColors.primaryLight,

      disabledColor: AppColors.divider,

      labelStyle: const TextStyle(color: AppColors.textPrimary),

      side: BorderSide.none,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    // ---------------- Snackbar ----------------
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.white,

      elevation: 0,

      behavior: SnackBarBehavior.floating,

      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // ---------------- Progress ----------------
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.sliderInactive,
    ),

    // ---------------- Checkbox ----------------
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),

    // ---------------- Switch ----------------
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryLight;
        }
        return AppColors.sliderInactive;
      }),
    ),

    // ---------------- BottomSheet ----------------
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),

    // ---------------- Dialog ----------------
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
