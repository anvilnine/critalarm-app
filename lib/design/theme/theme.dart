import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/radii.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

const PageTransitionsTheme? _webPageTransitions = kIsWeb
    ? PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: _NoTransitionsBuilder(),
          TargetPlatform.macOS: _NoTransitionsBuilder(),
        },
      )
    : null;

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Builds the light [ThemeData] for Crit Alarm.
ThemeData buildLightTheme({SeverityMode severity = SeverityMode.none}) =>
    _buildTheme(AppColors.light.withSeverity(severity), Brightness.light);

/// Builds the dark [ThemeData] for Crit Alarm.
ThemeData buildDarkTheme({SeverityMode severity = SeverityMode.none}) =>
    _buildTheme(AppColors.dark.withSeverity(severity), Brightness.dark);

ThemeData _buildTheme(AppColors colors, Brightness brightness) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: colors.highlight,
    onPrimary: colors.onHighlight,
    secondary: colors.cobalt,
    onSecondary: colors.onHighlight,
    error: colors.crit,
    onError: colors.onHighlight,
    surface: colors.surface,
    onSurface: colors.onCanvas,
    surfaceContainerHighest: colors.cream,
    outline: colors.hairline,
  );
  final textTheme = AppTypography.textTheme(colors.onCanvas);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    pageTransitionsTheme: _webPageTransitions,
    scaffoldBackgroundColor: colors.canvas,
    textTheme: textTheme,
    dividerTheme: DividerThemeData(color: colors.hairline, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colors.onCanvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppTypography.title(colors.onCanvas),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: Radii.xlAll,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: Radii.fullAll,
      ),
      backgroundColor: colors.surface,
      labelStyle: AppTypography.mono(colors.ink, fontSize: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: Radii.fullAll),
        backgroundColor: colors.highlight,
        foregroundColor: colors.onHighlight,
      ),
    ),
    extensions: [colors],
  );
}
