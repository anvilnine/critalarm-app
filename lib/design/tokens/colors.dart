import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Severity mode for canvas and face retinting.
enum SeverityMode {
  none,
  high,
  crit,
  ack,
}

/// Semantic color tokens for the Crit Alarm Design System.
/// Exposed as a [ThemeExtension] so UI reads `context.appColors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    // Canvas
    required this.canvas,
    required this.canvasAlt,
    required this.canvasGhost,
    required this.canvasGhostStrong,
    required this.yellow,
    // Surfaces
    required this.surface,
    required this.cream,
    required this.ash,
    required this.panel,
    required this.onPanel,
    required this.onPanelMuted,
    // Ink
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.inkHover,
    required this.onCanvas,
    required this.onCanvasMuted,
    // Cobalt / Highlight
    required this.cobalt,
    required this.cobaltHover,
    required this.cobaltTint,
    required this.highlight,
    required this.highlightHover,
    required this.highlightAlt,
    required this.onHighlight,
    required this.highlightShadow,
    // Severity ladder
    required this.high,
    required this.highAlt,
    required this.crit,
    required this.critAlt,
    required this.critTint,
    // Severity canvas rungs
    required this.highCanvas,
    required this.highCanvasAlt,
    required this.highStroke,
    required this.critCanvas,
    required this.critCanvasAlt,
    required this.critStroke,
    required this.ackCanvas,
    required this.ackCanvasAlt,
    required this.ackStroke,
    required this.ackText,
    required this.ackTextMuted,
    required this.ackGhost,
    required this.ackGhostStrong,
    // Face
    required this.faceFill,
    required this.faceStroke,
    required this.faceInk,
    // Fixed values
    required this.inkFixed,
    required this.cobaltOnDark,
    required this.codeString,
    required this.panelLine,
    required this.panelHover,
    // Lines & Focus
    required this.hairline,
    required this.focus,
    required this.focusGap,
    // Backwards-compatible placeholder slots
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

  // Canvas
  final Color canvas;
  final Color canvasAlt;
  final Color canvasGhost;
  final Color canvasGhostStrong;
  final Color yellow;

  // Surfaces
  final Color surface;
  final Color cream;
  final Color ash;
  final Color panel;
  final Color onPanel;
  final Color onPanelMuted;

  // Ink
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color inkHover;
  final Color onCanvas;
  final Color onCanvasMuted;

  // Cobalt / Highlight
  final Color cobalt;
  final Color cobaltHover;
  final Color cobaltTint;
  final Color highlight;
  final Color highlightHover;
  final Color highlightAlt;
  final Color onHighlight;
  final Color highlightShadow;

  // Severity ladder
  final Color high;
  final Color highAlt;
  final Color crit;
  final Color critAlt;
  final Color critTint;

  // Severity canvas rungs
  final Color highCanvas;
  final Color highCanvasAlt;
  final Color highStroke;
  final Color critCanvas;
  final Color critCanvasAlt;
  final Color critStroke;
  final Color ackCanvas;
  final Color ackCanvasAlt;
  final Color ackStroke;
  final Color ackText;
  final Color ackTextMuted;
  final Color ackGhost;
  final Color ackGhostStrong;

  // Face
  final Color faceFill;
  final Color faceStroke;
  final Color faceInk;

  // Fixed values
  final Color inkFixed;
  final Color cobaltOnDark;
  final Color codeString;
  final Color panelLine;
  final Color panelHover;

  // Lines & Focus
  final Color hairline;
  final Color focus;
  final Color focusGap;

  // Backwards-compatible placeholder slots
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color onSurfaceFaint;
  final Color surfaceContainer;
  final Color surfaceElevated;
  final Color tile;
  final Color primary;
  final Color onPrimary;
  final Color primaryShadow;
  final Color paper;
  final Color onPaper;
  final Color outline;
  final Color error;
  final Color onError;
  final Color positiveDelta;
  final Color negativeDelta;
  final Color confidenceHigh;
  final Color confidenceMedium;
  final Color confidenceLow;

  /// Light theme palette from docs/design-system/index.html.
  static const AppColors light = AppColors(
    // Canvas
    canvas: Color(0xFFFFC93C),
    canvasAlt: Color(0xFFFFD866),
    canvasGhost: Color(0x121A140F), // rgba(26,20,15,.07)
    canvasGhostStrong: Color(0x1F1A140F), // rgba(26,20,15,.12)
    yellow: Color(0xFFFFC93C),
    // Surfaces
    surface: Color(0xFFFFFFFF),
    cream: Color(0xFFF7F2E9),
    ash: Color(0xFFF1EFEC),
    panel: Color(0xFF1A140F),
    onPanel: Color(0xFFF7F1EA),
    onPanelMuted: Color(0xFFCBBDAF),
    // Ink
    ink: Color(0xFF1A140F),
    ink2: Color(0xFF3E2C21),
    ink3: Color(0xFF6E543F),
    inkHover: Color(0xFF322820),
    onCanvas: Color(0xFF1A140F),
    onCanvasMuted: Color(0xFF3A2A12),
    // Cobalt / Highlight
    cobalt: Color(0xFF2A3BD8),
    cobaltHover: Color(0xFF1F2EB8),
    cobaltTint: Color(0xFFDCE0FF),
    highlight: Color(0xFF2A3BD8),
    highlightHover: Color(0xFF1F2EB8),
    highlightAlt: Color(0xFF3E4FE6),
    onHighlight: Color(0xFFFFFFFF),
    highlightShadow: Color(0x59141C6E), // rgba(20,28,110,.35)
    // Severity ladder
    high: Color(0xFFFF8A1F),
    highAlt: Color(0xFFFFA24D),
    crit: Color(0xFFF5473A),
    critAlt: Color(0xFFFF6A5E),
    critTint: Color(0x2EF5473A), // rgba(245,71,58,.18)
    // Severity canvas rungs
    highCanvas: Color(0xFFFF8A1F),
    highCanvasAlt: Color(0xFFFFA24D),
    highStroke: Color(0xFF1A140F),
    critCanvas: Color(0xFFF5473A),
    critCanvasAlt: Color(0xFFFF6A5E),
    critStroke: Color(0xFF1A140F),
    ackCanvas: Color(0xFF2A3BD8),
    ackCanvasAlt: Color(0xFF3E4FE6),
    ackStroke: Color(0xFFFFFFFF),
    ackText: Color(0xFFFFFFFF),
    ackTextMuted: Color(0xFFDCE0FF),
    ackGhost: Color(0x1AFFFFFF), // rgba(255,255,255,.10)
    ackGhostStrong: Color(0x29FFFFFF), // rgba(255,255,255,.16)
    // Face
    faceFill: Color(0xFFFFC93C),
    faceStroke: Color(0xFF1A140F),
    faceInk: Color(0xFF1A140F),
    // Fixed
    inkFixed: Color(0xFF1A140F),
    cobaltOnDark: Color(0xFF7C8AFF),
    codeString: Color(0xFF9CC4FF),
    panelLine: Color(0x38FFFFFF), // rgba(255,255,255,.22)
    panelHover: Color(0x1AFFFFFF), // rgba(255,255,255,.10)
    // Lines & Focus
    hairline: Color(0x241A140F), // rgba(26,20,15,.14)
    focus: Color(0xFF2A3BD8),
    focusGap: Color(0xFFFFC93C),
    // Backwards compatibility
    onSurface: Color(0xFF1A140F),
    onSurfaceMuted: Color(0xFF3E2C21),
    onSurfaceFaint: Color(0xFF6E543F),
    surfaceContainer: Color(0xFFF7F2E9),
    surfaceElevated: Color(0xFFFFFFFF),
    tile: Color(0xFFFFFFFF),
    primary: Color(0xFF2A3BD8),
    onPrimary: Color(0xFFFFFFFF),
    primaryShadow: Color(0x59141C6E),
    paper: Color(0xFFFFFFFF),
    onPaper: Color(0xFF1A140F),
    outline: Color(0x241A140F),
    error: Color(0xFFF5473A),
    onError: Color(0xFFFFFFFF),
    positiveDelta: Color(0xFF2A3BD8),
    negativeDelta: Color(0xFFF5473A),
    confidenceHigh: Color(0xFFFF8A1F),
    confidenceMedium: Color(0xFFFFC93C),
    confidenceLow: Color(0xFFF5473A),
  );

  /// Dark theme palette from docs/design-system/index.html.
  static const AppColors dark = AppColors(
    // Canvas
    canvas: Color(0xFF171310),
    canvasAlt: Color(0xFF201A15),
    canvasGhost: Color(0x0CFFFFFF), // rgba(255,255,255,.045)
    canvasGhostStrong: Color(0x14FFFFFF), // rgba(255,255,255,.08)
    yellow: Color(0xFFFFC93C),
    // Surfaces
    surface: Color(0xFF241D18),
    cream: Color(0xFF241D18),
    ash: Color(0xFF2E2620),
    panel: Color(0xFF0E0B09),
    onPanel: Color(0xFFF7F1EA),
    onPanelMuted: Color(0xFFCBBDAF),
    // Ink
    ink: Color(0xFFF7F1EA),
    ink2: Color(0xFFCBBDAF),
    ink3: Color(0xFF9A8877),
    inkHover: Color(0xFFFFFFFF),
    onCanvas: Color(0xFFF7F1EA),
    onCanvasMuted: Color(0xFFCBBDAF),
    // Cobalt / Highlight
    cobalt: Color(0xFF7C8AFF),
    cobaltHover: Color(0xFF98A3FF),
    cobaltTint: Color(0x297C8AFF), // rgba(124,138,255,.16)
    highlight: Color(0xFF2A3BD8),
    highlightHover: Color(0xFF3E4FE6),
    highlightAlt: Color(0xFF3E4FE6),
    onHighlight: Color(0xFFFFFFFF),
    highlightShadow: Color(0x80000000), // rgba(0,0,0,.5)
    // Severity ladder
    high: Color(0xFFFF8A1F),
    highAlt: Color(0xFFFFA24D),
    crit: Color(0xFFF5473A),
    critAlt: Color(0xFFFF6A5E),
    critTint: Color(0x2EF5473A),
    // Severity canvas rungs
    highCanvas: Color(0xFF3A2208),
    highCanvasAlt: Color(0xFF4A2C0C),
    highStroke: Color(0xFFD97A1A),
    critCanvas: Color(0xFF3A100D),
    critCanvasAlt: Color(0xFF4C1511),
    critStroke: Color(0xFFE0483A),
    ackCanvas: Color(0xFF141A4A),
    ackCanvasAlt: Color(0xFF1B2260),
    ackStroke: Color(0xFF7C8AFF),
    ackText: Color(0xFFF7F1EA),
    ackTextMuted: Color(0xFFCBBDAF),
    ackGhost: Color(0x0CFFFFFF),
    ackGhostStrong: Color(0x14FFFFFF),
    // Face
    faceFill: Color(0xFF241D18),
    faceStroke: Color(0xFFB08A22),
    faceInk: Color(0xFFF7F1EA),
    // Fixed
    inkFixed: Color(0xFF1A140F),
    cobaltOnDark: Color(0xFF7C8AFF),
    codeString: Color(0xFF9CC4FF),
    panelLine: Color(0x38FFFFFF),
    panelHover: Color(0x1AFFFFFF),
    // Lines & Focus
    hairline: Color(0x24FFFFFF), // rgba(255,255,255,.14)
    focus: Color(0xFF7C8AFF),
    focusGap: Color(0xFF171310),
    // Backwards compatibility
    onSurface: Color(0xFFF7F1EA),
    onSurfaceMuted: Color(0xFFCBBDAF),
    onSurfaceFaint: Color(0xFF9A8877),
    surfaceContainer: Color(0xFF241D18),
    surfaceElevated: Color(0xFF2E2620),
    tile: Color(0xFF241D18),
    primary: Color(0xFF2A3BD8),
    onPrimary: Color(0xFFFFFFFF),
    primaryShadow: Color(0x80000000),
    paper: Color(0xFF241D18),
    onPaper: Color(0xFFF7F1EA),
    outline: Color(0x24FFFFFF),
    error: Color(0xFFF5473A),
    onError: Color(0xFFFFFFFF),
    positiveDelta: Color(0xFF7C8AFF),
    negativeDelta: Color(0xFFF5473A),
    confidenceHigh: Color(0xFFFF8A1F),
    confidenceMedium: Color(0xFFFFC93C),
    confidenceLow: Color(0xFFF5473A),
  );

  /// Retints the canvas palette according to [SeverityMode].
  AppColors withSeverity(SeverityMode mode) {
    switch (mode) {
      case SeverityMode.none:
        return this;
      case SeverityMode.high:
        return copyWith(
          canvas: highCanvas,
          canvasAlt: highCanvasAlt,
          faceStroke: highStroke,
          focusGap: highCanvas,
        );
      case SeverityMode.crit:
        return copyWith(
          canvas: critCanvas,
          canvasAlt: critCanvasAlt,
          faceStroke: critStroke,
          focusGap: critCanvas,
        );
      case SeverityMode.ack:
        return copyWith(
          canvas: ackCanvas,
          canvasAlt: ackCanvasAlt,
          onCanvas: ackText,
          onCanvasMuted: ackTextMuted,
          faceStroke: ackStroke,
          faceInk: ackText,
          canvasGhost: ackGhost,
          canvasGhostStrong: ackGhostStrong,
          focus: ackText,
          focusGap: ackCanvas,
        );
    }
  }

  @override
  AppColors copyWith({
    Color? canvas,
    Color? canvasAlt,
    Color? canvasGhost,
    Color? canvasGhostStrong,
    Color? yellow,
    Color? surface,
    Color? cream,
    Color? ash,
    Color? panel,
    Color? onPanel,
    Color? onPanelMuted,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? inkHover,
    Color? onCanvas,
    Color? onCanvasMuted,
    Color? cobalt,
    Color? cobaltHover,
    Color? cobaltTint,
    Color? highlight,
    Color? highlightHover,
    Color? highlightAlt,
    Color? onHighlight,
    Color? highlightShadow,
    Color? high,
    Color? highAlt,
    Color? crit,
    Color? critAlt,
    Color? critTint,
    Color? highCanvas,
    Color? highCanvasAlt,
    Color? highStroke,
    Color? critCanvas,
    Color? critCanvasAlt,
    Color? critStroke,
    Color? ackCanvas,
    Color? ackCanvasAlt,
    Color? ackStroke,
    Color? ackText,
    Color? ackTextMuted,
    Color? ackGhost,
    Color? ackGhostStrong,
    Color? faceFill,
    Color? faceStroke,
    Color? faceInk,
    Color? inkFixed,
    Color? cobaltOnDark,
    Color? codeString,
    Color? panelLine,
    Color? panelHover,
    Color? hairline,
    Color? focus,
    Color? focusGap,
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
      canvas: canvas ?? this.canvas,
      canvasAlt: canvasAlt ?? this.canvasAlt,
      canvasGhost: canvasGhost ?? this.canvasGhost,
      canvasGhostStrong: canvasGhostStrong ?? this.canvasGhostStrong,
      yellow: yellow ?? this.yellow,
      surface: surface ?? this.surface,
      cream: cream ?? this.cream,
      ash: ash ?? this.ash,
      panel: panel ?? this.panel,
      onPanel: onPanel ?? this.onPanel,
      onPanelMuted: onPanelMuted ?? this.onPanelMuted,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      inkHover: inkHover ?? this.inkHover,
      onCanvas: onCanvas ?? this.onCanvas,
      onCanvasMuted: onCanvasMuted ?? this.onCanvasMuted,
      cobalt: cobalt ?? this.cobalt,
      cobaltHover: cobaltHover ?? this.cobaltHover,
      cobaltTint: cobaltTint ?? this.cobaltTint,
      highlight: highlight ?? this.highlight,
      highlightHover: highlightHover ?? this.highlightHover,
      highlightAlt: highlightAlt ?? this.highlightAlt,
      onHighlight: onHighlight ?? this.onHighlight,
      highlightShadow: highlightShadow ?? this.highlightShadow,
      high: high ?? this.high,
      highAlt: highAlt ?? this.highAlt,
      crit: crit ?? this.crit,
      critAlt: critAlt ?? this.critAlt,
      critTint: critTint ?? this.critTint,
      highCanvas: highCanvas ?? this.highCanvas,
      highCanvasAlt: highCanvasAlt ?? this.highCanvasAlt,
      highStroke: highStroke ?? this.highStroke,
      critCanvas: critCanvas ?? this.critCanvas,
      critCanvasAlt: critCanvasAlt ?? this.critCanvasAlt,
      critStroke: critStroke ?? this.critStroke,
      ackCanvas: ackCanvas ?? this.ackCanvas,
      ackCanvasAlt: ackCanvasAlt ?? this.ackCanvasAlt,
      ackStroke: ackStroke ?? this.ackStroke,
      ackText: ackText ?? this.ackText,
      ackTextMuted: ackTextMuted ?? this.ackTextMuted,
      ackGhost: ackGhost ?? this.ackGhost,
      ackGhostStrong: ackGhostStrong ?? this.ackGhostStrong,
      faceFill: faceFill ?? this.faceFill,
      faceStroke: faceStroke ?? this.faceStroke,
      faceInk: faceInk ?? this.faceInk,
      inkFixed: inkFixed ?? this.inkFixed,
      cobaltOnDark: cobaltOnDark ?? this.cobaltOnDark,
      codeString: codeString ?? this.codeString,
      panelLine: panelLine ?? this.panelLine,
      panelHover: panelHover ?? this.panelHover,
      hairline: hairline ?? this.hairline,
      focus: focus ?? this.focus,
      focusGap: focusGap ?? this.focusGap,
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
      canvas: Color.lerp(canvas, other.canvas, t)!,
      canvasAlt: Color.lerp(canvasAlt, other.canvasAlt, t)!,
      canvasGhost: Color.lerp(canvasGhost, other.canvasGhost, t)!,
      canvasGhostStrong: Color.lerp(
        canvasGhostStrong,
        other.canvasGhostStrong,
        t,
      )!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      ash: Color.lerp(ash, other.ash, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      onPanel: Color.lerp(onPanel, other.onPanel, t)!,
      onPanelMuted: Color.lerp(onPanelMuted, other.onPanelMuted, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      inkHover: Color.lerp(inkHover, other.inkHover, t)!,
      onCanvas: Color.lerp(onCanvas, other.onCanvas, t)!,
      onCanvasMuted: Color.lerp(onCanvasMuted, other.onCanvasMuted, t)!,
      cobalt: Color.lerp(cobalt, other.cobalt, t)!,
      cobaltHover: Color.lerp(cobaltHover, other.cobaltHover, t)!,
      cobaltTint: Color.lerp(cobaltTint, other.cobaltTint, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      highlightHover: Color.lerp(highlightHover, other.highlightHover, t)!,
      highlightAlt: Color.lerp(highlightAlt, other.highlightAlt, t)!,
      onHighlight: Color.lerp(onHighlight, other.onHighlight, t)!,
      highlightShadow: Color.lerp(highlightShadow, other.highlightShadow, t)!,
      high: Color.lerp(high, other.high, t)!,
      highAlt: Color.lerp(highAlt, other.highAlt, t)!,
      crit: Color.lerp(crit, other.crit, t)!,
      critAlt: Color.lerp(critAlt, other.critAlt, t)!,
      critTint: Color.lerp(critTint, other.critTint, t)!,
      highCanvas: Color.lerp(highCanvas, other.highCanvas, t)!,
      highCanvasAlt: Color.lerp(highCanvasAlt, other.highCanvasAlt, t)!,
      highStroke: Color.lerp(highStroke, other.highStroke, t)!,
      critCanvas: Color.lerp(critCanvas, other.critCanvas, t)!,
      critCanvasAlt: Color.lerp(critCanvasAlt, other.critCanvasAlt, t)!,
      critStroke: Color.lerp(critStroke, other.critStroke, t)!,
      ackCanvas: Color.lerp(ackCanvas, other.ackCanvas, t)!,
      ackCanvasAlt: Color.lerp(ackCanvasAlt, other.ackCanvasAlt, t)!,
      ackStroke: Color.lerp(ackStroke, other.ackStroke, t)!,
      ackText: Color.lerp(ackText, other.ackText, t)!,
      ackTextMuted: Color.lerp(ackTextMuted, other.ackTextMuted, t)!,
      ackGhost: Color.lerp(ackGhost, other.ackGhost, t)!,
      ackGhostStrong: Color.lerp(ackGhostStrong, other.ackGhostStrong, t)!,
      faceFill: Color.lerp(faceFill, other.faceFill, t)!,
      faceStroke: Color.lerp(faceStroke, other.faceStroke, t)!,
      faceInk: Color.lerp(faceInk, other.faceInk, t)!,
      inkFixed: Color.lerp(inkFixed, other.inkFixed, t)!,
      cobaltOnDark: Color.lerp(cobaltOnDark, other.cobaltOnDark, t)!,
      codeString: Color.lerp(codeString, other.codeString, t)!,
      panelLine: Color.lerp(panelLine, other.panelLine, t)!,
      panelHover: Color.lerp(panelHover, other.panelHover, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      focusGap: Color.lerp(focusGap, other.focusGap, t)!,
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

/// Helper extension on BuildContext to quickly access [AppColors].
extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// WCAG 2.2 Relative Luminance and Contrast calculation utilities.
abstract final class ColorContrast {
  static double relativeLuminance(Color color) {
    double transform(double val) => val <= 0.03928
        ? val / 12.92
        : math.pow((val + 0.055) / 1.055, 2.4).toDouble();

    // Use floating point RGB (0.0 to 1.0)
    final r = transform(color.r);
    final g = transform(color.g);
    final b = transform(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double contrastRatio(Color fg, Color bg) {
    final l1 = relativeLuminance(fg);
    final l2 = relativeLuminance(bg);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static String wcagGrade(double ratio) {
    if (ratio >= 7.0) return 'AAA';
    if (ratio >= 4.5) return 'AA';
    if (ratio >= 3.0) return 'AA large';
    return 'fail';
  }
}
