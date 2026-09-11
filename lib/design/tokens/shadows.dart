import 'package:flutter/widgets.dart';

/// Elevation shadow tokens for Crit Alarm Design System.
/// Warm shadows on light themes (rgba(38,22,10)), deeper black shadows on dark.
abstract final class AppShadows {
  // Light theme shadows
  static const List<BoxShadow> lightSm = [
    BoxShadow(
      color: Color(0x1A26160A), // rgba(38,22,10,.10)
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
    BoxShadow(
      color: Color(0x0F26160A), // rgba(38,22,10,.06)
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static const List<BoxShadow> lightMd = [
    BoxShadow(
      color: Color(0x2426160A), // rgba(38,22,10,.14)
      offset: Offset(0, 8),
      blurRadius: 22,
    ),
    BoxShadow(
      color: Color(0x1426160A), // rgba(38,22,10,.08)
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  static const List<BoxShadow> lightLg = [
    BoxShadow(
      color: Color(0x2E26160A), // rgba(38,22,10,.18)
      offset: Offset(0, 18),
      blurRadius: 44,
    ),
    BoxShadow(
      color: Color(0x1A26160A), // rgba(38,22,10,.10)
      offset: Offset(0, 6),
      blurRadius: 14,
    ),
  ];

  // Dark theme shadows
  static const List<BoxShadow> darkSm = [
    BoxShadow(
      color: Color(0x4D000000), // rgba(0,0,0,.3)
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  static const List<BoxShadow> darkMd = [
    BoxShadow(
      color: Color(0x66000000), // rgba(0,0,0,.4)
      offset: Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  static const List<BoxShadow> darkLg = [
    BoxShadow(
      color: Color(0x80000000), // rgba(0,0,0,.5)
      offset: Offset(0, 18),
      blurRadius: 40,
    ),
  ];

  // Convenience getters defaulting to light
  static const List<BoxShadow> sm = lightSm;
  static const List<BoxShadow> md = lightMd;
  static const List<BoxShadow> lg = lightLg;

  /// Returns theme-appropriate shadows for the given [isDark] setting.
  static List<BoxShadow> shadowSm({bool isDark = false}) =>
      isDark ? darkSm : lightSm;
  static List<BoxShadow> shadowMd({bool isDark = false}) =>
      isDark ? darkMd : lightMd;
  static List<BoxShadow> shadowLg({bool isDark = false}) =>
      isDark ? darkLg : lightLg;
}
