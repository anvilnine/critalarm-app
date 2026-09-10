import 'package:flutter/material.dart';

/// Upper bound on text scaling for fixed-height chrome (the bottom tab bar):
/// the bar is a fixed 58pt surface flanking the capture plate, so unbounded
/// user text scaling would overflow it and crowd the plate. Content still
/// honours smaller-than-1.0 and up-to-this-ceiling user scale settings.
const double kChromeMaxTextScale = 1.3;

/// Typography tokens.
///
/// PLACEHOLDER FACES: the three families below are stand-ins.
/// docs/design-system/NOTES.md calls for Bricolage Grotesque 800 for
/// display, Instrument Sans 400 to 600 for body, and JetBrains Mono for every
/// string a machine could consume (topic names, endpoints, tokens, timestamps,
/// priorities). A0 swaps the asset files and the three constants below.
///
/// Faces are bundled asset fonts (see `pubspec.yaml` `fonts:`), not fetched at
/// runtime, so the first frame paints with the final faces. Keep it that way:
/// an alarm screen must not wait on a font download.
abstract final class AppTypography {
  static const String _anton = 'Anton';
  static const String _archivo = 'Archivo';
  static const String _ibmPlexMono = 'IBMPlexMono';

  static TextTheme textTheme(Color onSurface) {
    final body = ThemeData(useMaterial3: true).textTheme.apply(
      fontFamily: _archivo,
    );
    TextStyle? disp(TextStyle? base) => base?.copyWith(fontFamily: _anton);
    return body
        .copyWith(
          displayLarge: disp(body.displayLarge),
          displayMedium: disp(body.displayMedium),
          headlineMedium: disp(body.headlineMedium),
          titleLarge: disp(body.titleLarge)?.copyWith(letterSpacing: 0.6),
          titleMedium: disp(body.titleMedium)?.copyWith(
            fontSize: 16,
            letterSpacing: 0.6,
          ),
          labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);
  }

  /// For numbers that vertically align across rows.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Large numeric readout used by metric tiles + the dashboard hero.
  static TextStyle metricValue(Color color) => TextStyle(
    fontFamily: _anton,
    fontSize: 28,
    height: 1,
    color: color,
    fontFeatures: tabularFigures,
  );

  /// Anton metric scale — named sizes off [metricValue] (28). Use these
  /// instead of ad-hoc `metricValue(c).copyWith(fontSize: N)` at call sites.
  static TextStyle metricHero(Color color) =>
      metricValue(color).copyWith(fontSize: 76);
  static TextStyle metricLarge(Color color) =>
      metricValue(color).copyWith(fontSize: 52);
  static TextStyle metricDisplay(Color color) =>
      metricValue(color).copyWith(fontSize: 40);
  static TextStyle metricMedium(Color color) =>
      metricValue(color).copyWith(fontSize: 34);
  static TextStyle metricSmall(Color color) =>
      metricValue(color).copyWith(fontSize: 22);
  static TextStyle metricCompact(Color color) =>
      metricValue(color).copyWith(fontSize: 20);
  static TextStyle metricMini(Color color) =>
      metricValue(color).copyWith(fontSize: 18);
  static TextStyle metricCaption(Color color) =>
      metricValue(color).copyWith(fontSize: 16);

  /// Uppercase tracked eyebrow/label (callers pass uppercased text).
  static TextStyle eyebrow(Color color) => TextStyle(
    fontFamily: _archivo,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
    color: color,
  );

  /// Mono caption for units, timestamps, counts and data annotations.
  static TextStyle mono(Color color) => TextStyle(
    fontFamily: _ibmPlexMono,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    color: color,
  );

  /// Mono scale — named sizes off [mono] (11). Use instead of
  /// `mono(c).copyWith(fontSize: N)` at call sites.
  static TextStyle monoLarge(Color color) => mono(color).copyWith(fontSize: 16);
  static TextStyle monoMedium(Color color) =>
      mono(color).copyWith(fontSize: 14);
  static TextStyle monoSmall(Color color) => mono(color).copyWith(fontSize: 10);
}
