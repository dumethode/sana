import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sana/core/theme/app_colors.dart';
import 'package:sana/features/incidents/models/incident_enums.dart';

/// WCAG 2.2 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A translucent colour flattened onto a background.
Color over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

void main() {
  final meaning = <Color>{
    for (final c in IncidentCategory.values) c.color,
    for (final s in IncidentStatus.values) s.color,
    for (final s in Severity.values) s.color,
  };

  for (final palette in [SanaPalette.light, SanaPalette.dark]) {
    final brightness = palette == SanaPalette.light ? Brightness.light : Brightness.dark;

    test('${brightness.name}: pill text passes AA (4.5:1) on its own tint', () {
      for (final c in meaning) {
        final bg = over(SanaPalette.tint(c), palette.surface);
        final ratio = contrast(SanaPalette.onTint(c, brightness), bg);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '$c gives ${ratio.toStringAsFixed(2)}');
      }
    });

    test('${brightness.name}: button text on the accent passes AA', () {
      expect(contrast(palette.onSignal, palette.signal), greaterThanOrEqualTo(4.5));
    });

    test('${brightness.name}: body and secondary text pass AA on canvas and surface', () {
      for (final bg in [palette.canvas, palette.surface]) {
        expect(contrast(palette.ink, bg), greaterThanOrEqualTo(4.5));
        expect(contrast(palette.inkMuted, bg), greaterThanOrEqualTo(4.5));
      }
    });
  }
}
