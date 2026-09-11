import 'package:flutter/material.dart';

/// Upper bound on text scaling for fixed-height chrome.
const double kChromeMaxTextScale = 1.3;

/// Typography tokens for Crit Alarm Design System.
/// Display: Bricolage Grotesque 800 (fallback Anton / Archivo).
/// Body: Instrument Sans 400-600 (fallback Archivo).
/// Mono: JetBrains Mono 500/700 (fallback IBMPlexMono).
abstract final class AppTypography {
  // Primary font families
  static const String fontDisplay = 'Bricolage Grotesque';
  static const String fontBody = 'Instrument Sans';
  static const String fontMono = 'JetBrains Mono';

  // Bundled fallback families
  static const List<String> fontDisplayFallbacks = [
    'Anton',
    'Archivo',
    'sans-serif',
  ];
  static const List<String> fontBodyFallbacks = ['Archivo', 'sans-serif'];
  static const List<String> fontMonoFallbacks = ['IBMPlexMono', 'monospace'];

  // Legacy family names for backward compatibility
  static const String _anton = 'Anton';
  static const String _archivo = 'Archivo';

  /// Display 800 (hero / wake up headlines).
  static TextStyle display(Color color, {double fontSize = 56}) => TextStyle(
    fontFamily: fontDisplay,
    fontFamilyFallback: fontDisplayFallbacks,
    fontWeight: FontWeight.w800,
    fontSize: fontSize,
    height: 0.95,
    letterSpacing: -0.04 * fontSize,
    color: color,
  );

  /// Headline 800 (section and card headers).
  static TextStyle headline(Color color, {double fontSize = 36}) => TextStyle(
    fontFamily: fontDisplay,
    fontFamilyFallback: fontDisplayFallbacks,
    fontWeight: FontWeight.w800,
    fontSize: fontSize,
    height: 1.05,
    letterSpacing: -0.03 * fontSize,
    color: color,
  );

  /// Title 700 (card titles, dialogue headers).
  static TextStyle title(Color color, {double fontSize = 20}) => TextStyle(
    fontFamily: fontDisplay,
    fontFamilyFallback: fontDisplayFallbacks,
    fontWeight: FontWeight.w700,
    fontSize: fontSize,
    height: 1.2,
    letterSpacing: -0.02 * fontSize,
    color: color,
  );

  /// Lead 500 (introductory prose, hero subtitles).
  static TextStyle lead(Color color, {double fontSize = 18}) => TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: fontBodyFallbacks,
    fontWeight: FontWeight.w500,
    fontSize: fontSize,
    height: 1.5,
    color: color,
  );

  /// Body 400 (standard prose).
  static TextStyle body(Color color, {double fontSize = 16}) => TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: fontBodyFallbacks,
    fontWeight: FontWeight.w400,
    fontSize: fontSize,
    height: 1.6,
    color: color,
  );

  /// Small 500 (captions, notes, metadata).
  static TextStyle small(Color color, {double fontSize = 14}) => TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: fontBodyFallbacks,
    fontWeight: FontWeight.w500,
    fontSize: fontSize,
    height: 1.4,
    color: color,
  );

  /// Label 700 caps (eyebrows, badges, pill tags).
  static TextStyle label(Color color, {double fontSize = 11}) => TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: fontBodyFallbacks,
    fontWeight: FontWeight.w700,
    fontSize: fontSize,
    letterSpacing: 1,
    height: 1.2,
    color: color,
  );

  /// Mono 500 (topics, endpoints, curl strings).
  static TextStyle mono(Color color, {double fontSize = 14}) => TextStyle(
    fontFamily: fontMono,
    fontFamilyFallback: fontMonoFallbacks,
    fontWeight: FontWeight.w500,
    fontSize: fontSize,
    height: 1.5,
    letterSpacing: -0.01 * fontSize,
    color: color,
  );

  /// Mono 700 (priority tags, bold tokens, timestamps).
  static TextStyle monoBold(Color color, {double fontSize = 14}) => TextStyle(
    fontFamily: fontMono,
    fontFamilyFallback: fontMonoFallbacks,
    fontWeight: FontWeight.w700,
    fontSize: fontSize,
    height: 1.5,
    letterSpacing: -0.01 * fontSize,
    color: color,
  );

  /// TextTheme constructor configuring standard Material text roles.
  static TextTheme textTheme(Color onSurface) {
    return TextTheme(
      displayLarge: display(onSurface, fontSize: 64),
      displayMedium: display(onSurface, fontSize: 48),
      displaySmall: headline(onSurface),
      headlineLarge: headline(onSurface, fontSize: 32),
      headlineMedium: headline(onSurface, fontSize: 28),
      headlineSmall: title(onSurface, fontSize: 22),
      titleLarge: title(onSurface),
      titleMedium: title(onSurface, fontSize: 16),
      titleSmall: title(onSurface, fontSize: 14),
      bodyLarge: body(onSurface),
      bodyMedium: body(onSurface, fontSize: 14),
      bodySmall: small(onSurface, fontSize: 12),
      labelLarge: label(onSurface, fontSize: 13),
      labelMedium: label(onSurface),
      labelSmall: label(onSurface, fontSize: 10),
    );
  }

  /// For numbers that vertically align across rows.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  // Backwards-compatible metric styles
  static TextStyle metricValue(Color color) => TextStyle(
    fontFamily: _anton,
    fontSize: 28,
    height: 1,
    color: color,
    fontFeatures: tabularFigures,
  );

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

  static TextStyle eyebrow(Color color) => TextStyle(
    fontFamily: _archivo,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
    color: color,
  );

  static TextStyle monoLarge(Color color) => mono(color, fontSize: 16);
  static TextStyle monoMedium(Color color) => mono(color);
  static TextStyle monoSmall(Color color) => mono(color, fontSize: 10);
}
