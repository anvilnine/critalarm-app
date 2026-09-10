import 'package:critalarm/design_system/tokens/colors.dart';
import 'package:critalarm/design_system/tokens/radii.dart';
import 'package:critalarm/design_system/tokens/typography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// On web, iOS/macOS default to `CupertinoPageTransitionsBuilder`, whose
/// interactive edge-swipe back fights the browser/PWA history-swipe gesture:
/// a single edge-swipe fires both, so go_router pops while the browser also
/// navigates — the page re-navigates forward or the outgoing page flicker-
/// plays its exit animation (M28 item 3). On web the browser/OS already
/// animates the swipe itself, so Flutter renders no transition at all —
/// history is driven solely by the browser. Native iOS keeps the Cupertino
/// swipe.
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

/// The only place ThemeData is constructed — solely from tokens.
ThemeData buildLightTheme() => _buildTheme(AppColors.light, Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(AppColors.dark, Brightness.dark);

ThemeData _buildTheme(AppColors colors, Brightness brightness) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    secondary: colors.primary,
    onSecondary: colors.onPrimary,
    error: colors.error,
    onError: colors.onError,
    surface: colors.surface,
    onSurface: colors.onSurface,
    surfaceContainerHighest: colors.surfaceElevated,
    outline: colors.outline,
  );
  final textTheme = AppTypography.textTheme(colors.onSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    // Web-only: kill the Cupertino edge-swipe on iOS/macOS (see above).
    // Null on native leaves ThemeData's per-platform defaults untouched.
    pageTransitionsTheme: _webPageTransitions,
    scaffoldBackgroundColor: colors.surface,
    textTheme: textTheme,
    dividerTheme: DividerThemeData(color: colors.outline, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceElevated,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(color: colors.outline),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: Radii.smAll,
        side: BorderSide(color: colors.outline),
      ),
      backgroundColor: colors.tile,
      selectedColor: colors.primary,
      checkmarkColor: colors.onPrimary,
      labelStyle: textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(
        color: colors.onPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        side: BorderSide(color: colors.outline),
        backgroundColor: colors.tile,
        foregroundColor: colors.onSurfaceMuted,
        selectedBackgroundColor: colors.primary,
        selectedForegroundColor: colors.onPrimary,
        textStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
    ),
    extensions: [colors],
  );
}
