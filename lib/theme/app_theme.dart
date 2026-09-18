import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium "liquid glass" palette.
class AppColors {
  AppColors._();

  static const Color ink = Color(0xFF05060F); // deep space background
  static const Color inkAlt = Color(0xFF0B0F22); // slightly lighter panel bg
  static const Color violet = Color(0xFF6C5CE7);
  static const Color cyan = Color(0xFF00D2FF);
  static const Color pink = Color(0xFFFF5FA2);
  static const Color mint = Color(0xFF3CF0B8);
  static const Color amber = Color(0xFFFFC24B);
  static const Color textPrimary = Color(0xFFF2F4FF);
  static const Color textMuted = Color(0xFF9AA3C7);
  static const Color danger = Color(0xFFFF5C7A);

  static const List<Color> aurora = [Color(0xFF2408A8), Color(0xFF0077E4), Color(0xFF00D2FF)];
  static const List<Color> gradientPrimary = [violet, Color(0xFF8F5EF7), cyan];
  static const List<Color> gradientAccent = [pink, Color(0xFFB44BFF), cyan];
}

/// Theme data for the whole app.
ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: ColorScheme.dark(
      primary: AppColors.violet,
      secondary: AppColors.cyan,
      surface: AppColors.inkAlt,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(color: AppColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: -1.2),
      headlineMedium: GoogleFonts.spaceGrotesk(color: AppColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      titleLarge: GoogleFonts.spaceGrotesk(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.spaceGrotesk(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.inkAlt.withOpacity(0.9),
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: Colors.white10),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.violet),
  );
}