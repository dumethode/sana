import 'package:flutter/material.dart';

/// Raw colour tokens from docs/DESIGN.md. Widgets read colours through
/// [SanaPalette] (a ThemeExtension) so light and dark themes stay in sync.
abstract final class AppColors {
  static const signalLight = Color(0xFFC2410C);
  static const signalDark = Color(0xFFFF6A33);

  static const statusSubmitted = Color(0xFF64748B);
  static const statusAcknowledged = Color(0xFF4F46E5);
  static const statusInProgress = Color(0xFFC27803);
  static const statusResolved = Color(0xFF15803D);
  static const statusRejected = Color(0xFFB42318);

  static const water = Color(0xFF0284C7);
  static const electricity = Color(0xFFCA8A04);
  static const facilities = Color(0xFF8B5E34);
  static const sanitation = Color(0xFF0F766E);
  static const safety = Color(0xFFDC2626);
  static const internet = Color(0xFF7C3AED);
  static const other = Color(0xFF475569);
}

/// Surface-level tokens that differ between light and dark mode.
@immutable
class SanaPalette extends ThemeExtension<SanaPalette> {
  const SanaPalette({
    required this.canvas,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.signal,
    required this.onSignal,
  });

  final Color canvas;
  final Color surface;
  final Color ink;
  final Color inkMuted;
  final Color line;
  final Color signal;

  /// Text and icons placed on [signal]. White on the light accent (5.2:1),
  /// near-black on the brighter dark-mode accent (6.6:1).
  final Color onSignal;

  static const light = SanaPalette(
    canvas: Color(0xFFF4F2ED),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF0B1F3A),
    inkMuted: Color(0xFF5A6373),
    line: Color(0xFFE2DED5),
    signal: AppColors.signalLight,
    onSignal: Color(0xFFFFFFFF),
  );

  static const dark = SanaPalette(
    canvas: Color(0xFF0E1116),
    surface: Color(0xFF161A21),
    ink: Color(0xFFE7ECF3),
    inkMuted: Color(0xFF9AA4B2),
    line: Color(0xFF262C36),
    signal: AppColors.signalDark,
    onSignal: Color(0xFF0E1116),
  );

  /// A 12% tint used behind coloured text (chips, stubs, pills).
  static Color tint(Color c) => c.withValues(alpha: 0.12);

  /// The readable version of a meaning colour (status, category, severity)
  /// when it sits on its own 12% tint: darkened in light mode, lightened in
  /// dark mode. Every pair reaches at least 4.8:1 (WCAG 2.2 AA for text).
  static Color onTint(Color c, Brightness b) => b == Brightness.dark
      ? Color.lerp(c, const Color(0xFFFFFFFF), 0.35)!
      : Color.lerp(c, const Color(0xFF000000), 0.3)!;

  @override
  SanaPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? ink,
    Color? inkMuted,
    Color? line,
    Color? signal,
    Color? onSignal,
  }) {
    return SanaPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      line: line ?? this.line,
      signal: signal ?? this.signal,
      onSignal: onSignal ?? this.onSignal,
    );
  }

  @override
  SanaPalette lerp(ThemeExtension<SanaPalette>? other, double t) {
    if (other is! SanaPalette) return this;
    return SanaPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      line: Color.lerp(line, other.line, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      onSignal: Color.lerp(onSignal, other.onSignal, t)!,
    );
  }
}

extension SanaThemeX on BuildContext {
  SanaPalette get palette => Theme.of(this).extension<SanaPalette>()!;

  /// [SanaPalette.onTint] for the current brightness.
  Color onTint(Color c) => SanaPalette.onTint(c, Theme.of(this).brightness);
  TextTheme get text => Theme.of(this).textTheme;
}
