import 'package:flutter/material.dart';

/// Semantic color tokens, exposed as a [ThemeExtension] so feature code
/// reads `context.appColors` and never raw colors.
///
/// PLACEHOLDER VALUES: the colours below and several slot names are stand-ins.
/// The shape is what matters: a ThemeExtension with `copyWith` and `lerp`, so
/// swapping one AppColors instance above
/// MaterialApp retints the whole canvas and animates the change. That is the
/// seam severity retinting needs.
///
/// A0 replaces the values with docs/design-system/ (canvas #FFC93C, cobalt
/// #2A3BD8, orange #FF8A1F for high, red #F5473A for critical) and renames the
/// leftover slots (`confidenceHigh/Medium/Low`, the delta pair, `paper`) to
/// severity slots.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.onSurfaceFaint,
    required this.surfaceContainer,
    required this.surfaceElevated,
    required this.tile,
    required this.primary,
    required this.onPrimary,
    required this.primaryShadow,
    required this.paper,
    required this.onPaper,
    required this.outline,
    required this.error,
    required this.onError,
    required this.positiveDelta,
    required this.negativeDelta,
    required this.confidenceHigh,
    required this.confidenceMedium,
    required this.confidenceLow,
  });

  final Color surface;
  final Color onSurface;
  final Color onSurfaceMuted;

  /// Third text step (chalk-3): eyebrows, mono captions, deemphasis.
  final Color onSurfaceFaint;
  final Color surfaceContainer;
  final Color surfaceElevated;

  /// Metric tiles and field rows — one step above [surfaceElevated].
  final Color tile;
  final Color primary;
  final Color onPrimary;

  /// Hard offset shadow under accent plates (buttons).
  final Color primaryShadow;

  /// Paper-like surfaces, for quoted or printed-looking content.
  final Color paper;
  final Color onPaper;
  final Color outline;
  final Color error;
  final Color onError;

  /// A value moving in the user's favour. A0 remaps this to a severity slot.
  final Color positiveDelta;

  /// A measurement moving against the user.
  final Color negativeDelta;

  final Color confidenceHigh;
  final Color confidenceMedium;
  final Color confidenceLow;

  /// Light theme: pale paper ground, same accent, darkened status
  /// so status still reads on the light ground.
  static const AppColors light = AppColors(
    surface: Color(0xFFF2EFE9),
    onSurface: Color(0xFF1B1C1E),
    onSurfaceMuted: Color(0xFF5E5C55),
    onSurfaceFaint: Color(0xFF8A877C),
    surfaceContainer: Color(0xFFE9E5D8),
    surfaceElevated: Color(0xFFF9F7F0),
    tile: Color(0xFFFFFFFF),
    primary: Color(0xFFFF5A00),
    onPrimary: Color(0xFF141517),
    primaryShadow: Color(0xFFA33900),
    paper: Color(0xFFEDE7D6),
    onPaper: Color(0xFF1B1C1E),
    outline: Color(0xFFD9D3C3),
    error: Color(0xFFD93025),
    onError: Color(0xFFFFFFFF),
    positiveDelta: Color(0xFF6F8E14),
    negativeDelta: Color(0xFFD93025),
    confidenceHigh: Color(0xFF6F8E14),
    confidenceMedium: Color(0xFFC7920A),
    confidenceLow: Color(0xFFD93025),
  );

  /// The mat: near-black rubber, chalk text, taped-edge status.
  static const AppColors dark = AppColors(
    surface: Color(0xFF101112),
    onSurface: Color(0xFFF2EFE9),
    onSurfaceMuted: Color(0xFFB9B6AE),
    onSurfaceFaint: Color(0xFF7D7B75),
    surfaceContainer: Color(0xFF1B1C1E),
    surfaceElevated: Color(0xFF232527),
    tile: Color(0xFF2B2D30),
    primary: Color(0xFFFF5A00),
    onPrimary: Color(0xFF141517),
    primaryShadow: Color(0xFFA33900),
    paper: Color(0xFFEDE7D6),
    onPaper: Color(0xFF1B1C1E),
    outline: Color(0xFF3A3D41),
    error: Color(0xFFFF4747),
    onError: Color(0xFF141517),
    positiveDelta: Color(0xFFB5D33D),
    negativeDelta: Color(0xFFFF4747),
    confidenceHigh: Color(0xFFB5D33D),
    confidenceMedium: Color(0xFFFFC933),
    confidenceLow: Color(0xFFFF4747),
  );

  @override
  AppColors copyWith({
    Color? surface,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? onSurfaceFaint,
    Color? surfaceContainer,
    Color? surfaceElevated,
    Color? tile,
    Color? primary,
    Color? onPrimary,
    Color? primaryShadow,
    Color? paper,
    Color? onPaper,
    Color? outline,
    Color? error,
    Color? onError,
    Color? positiveDelta,
    Color? negativeDelta,
    Color? confidenceHigh,
    Color? confidenceMedium,
    Color? confidenceLow,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      onSurfaceFaint: onSurfaceFaint ?? this.onSurfaceFaint,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      tile: tile ?? this.tile,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryShadow: primaryShadow ?? this.primaryShadow,
      paper: paper ?? this.paper,
      onPaper: onPaper ?? this.onPaper,
      outline: outline ?? this.outline,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      positiveDelta: positiveDelta ?? this.positiveDelta,
      negativeDelta: negativeDelta ?? this.negativeDelta,
      confidenceHigh: confidenceHigh ?? this.confidenceHigh,
      confidenceMedium: confidenceMedium ?? this.confidenceMedium,
      confidenceLow: confidenceLow ?? this.confidenceLow,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      onSurfaceFaint: Color.lerp(onSurfaceFaint, other.onSurfaceFaint, t)!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      tile: Color.lerp(tile, other.tile, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryShadow: Color.lerp(primaryShadow, other.primaryShadow, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      onPaper: Color.lerp(onPaper, other.onPaper, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      positiveDelta: Color.lerp(positiveDelta, other.positiveDelta, t)!,
      negativeDelta: Color.lerp(negativeDelta, other.negativeDelta, t)!,
      confidenceHigh: Color.lerp(confidenceHigh, other.confidenceHigh, t)!,
      confidenceMedium: Color.lerp(
        confidenceMedium,
        other.confidenceMedium,
        t,
      )!,
      confidenceLow: Color.lerp(confidenceLow, other.confidenceLow, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
