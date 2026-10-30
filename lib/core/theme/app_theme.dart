import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Font family names declared in pubspec.yaml (bundled, offline-safe).
abstract final class AppFonts {
  static const display = 'SpaceGrotesk';
  static const body = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
}

/// Spacing and radius scale from docs/DESIGN.md.
abstract final class Gap {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

abstract final class Radii {
  static const card = 14.0;
  static const control = 12.0;
}

/// Monospace style for reference codes, timestamps and overlines.
TextStyle monoStyle(BuildContext context, {Color? color, double size = 12}) {
  return TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: size,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    color: color ?? context.palette.inkMuted,
  );
}

abstract final class AppTheme {
  static ThemeData light() => _build(SanaPalette.light, Brightness.light);
  static ThemeData dark() => _build(SanaPalette.dark, Brightness.dark);

  static ThemeData _build(SanaPalette p, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.signal,
      brightness: brightness,
    ).copyWith(
      primary: p.signal,
      onPrimary: p.onSignal,
      surface: p.surface,
      onSurface: p.ink,
      outline: p.line,
      outlineVariant: p.line,
      error: AppColors.statusRejected,
    );

    final text = TextTheme(
      displaySmall: TextStyle(fontFamily: AppFonts.display, fontSize: 28, fontWeight: FontWeight.w700, color: p.ink, height: 1.15),
      headlineSmall: TextStyle(fontFamily: AppFonts.display, fontSize: 22, fontWeight: FontWeight.w600, color: p.ink, height: 1.2),
      titleLarge: TextStyle(fontFamily: AppFonts.display, fontSize: 19, fontWeight: FontWeight.w600, color: p.ink),
      titleMedium: TextStyle(fontFamily: AppFonts.display, fontSize: 17, fontWeight: FontWeight.w600, color: p.ink, height: 1.25),
      titleSmall: TextStyle(fontFamily: AppFonts.body, fontSize: 14, fontWeight: FontWeight.w600, color: p.ink),
      bodyLarge: TextStyle(fontFamily: AppFonts.body, fontSize: 16, color: p.ink, height: 1.45),
      bodyMedium: TextStyle(fontFamily: AppFonts.body, fontSize: 15, color: p.ink, height: 1.45),
      bodySmall: TextStyle(fontFamily: AppFonts.body, fontSize: 13, color: p.inkMuted, height: 1.4),
      labelLarge: TextStyle(fontFamily: AppFonts.body, fontSize: 15, fontWeight: FontWeight.w600, color: p.ink),
      labelMedium: TextStyle(fontFamily: AppFonts.body, fontSize: 13, fontWeight: FontWeight.w600, color: p.ink),
      labelSmall: TextStyle(fontFamily: AppFonts.body, fontSize: 12, fontWeight: FontWeight.w500, color: p.inkMuted),
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      textTheme: text,
      scaffoldBackgroundColor: p.canvas,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: p.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: 14),
        border: border(p.line),
        enabledBorder: border(p.line),
        focusedBorder: border(p.signal, 1.6),
        errorBorder: border(AppColors.statusRejected),
        focusedErrorBorder: border(AppColors.statusRejected, 1.6),
        labelStyle: text.bodyMedium?.copyWith(color: p.inkMuted),
        hintStyle: text.bodyMedium?.copyWith(color: p.inkMuted),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.signal,
          foregroundColor: p.onSignal,
          minimumSize: const Size.fromHeight(52),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: p.line),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.signal, textStyle: text.labelLarge),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: SanaPalette.tint(p.signal),
        side: BorderSide(color: p.line),
        labelStyle: text.labelMedium,
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: Gap.s, vertical: Gap.xs),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: SanaPalette.tint(p.signal),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(color: p.ink)),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.signal : p.inkMuted),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: SanaPalette.tint(p.signal),
        selectedIconTheme: IconThemeData(color: p.signal),
        unselectedIconTheme: IconThemeData(color: p.inkMuted),
        selectedLabelTextStyle: text.labelSmall?.copyWith(color: p.ink),
        unselectedLabelTextStyle: text.labelSmall,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card + 6)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.canvas),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: SanaPalette.tint(p.signal),
          selectedForegroundColor: p.ink,
          foregroundColor: p.inkMuted,
          backgroundColor: p.surface,
          side: BorderSide(color: p.line),
          textStyle: text.labelMedium,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.signal, linearTrackColor: p.line),
    );
  }
}
