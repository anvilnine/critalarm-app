import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/material.dart';

// Minimal: one plain canvas, near-white in the light theme and near-black
// in the dark one, with nothing behind the words. Ink and paper only. The
// yellow face is the one colour on the screen.

const Color _lightCanvas = Color(0xFFF6F3EE);
const Color _lightCanvasAlt = Color(0xFFEFEBE4);
const Color _darkCanvas = Color(0xFF0C0A08);
const Color _darkCanvasAlt = Color(0xFF14110E);
const Color _darkCard = Color(0xFF1E1915);

/// The rows inside the details card, one step off the card, dark enough
/// for the row labels to read on.
const Color _darkRow = Color(0xFF261F1A);

/// The same palette on both stages and for every severity: the stage is
/// told apart by the face and the words.
AppColors _minimalColors(
  AppColors base,
  SeverityMode severity,
  Brightness brightness,
) {
  if (brightness == Brightness.dark) {
    return base.copyWith(
      canvas: _darkCanvas,
      canvasAlt: _darkCanvasAlt,
      canvasGhost: AppColors.dark.canvasGhost,
      canvasGhostStrong: AppColors.dark.canvasGhostStrong,
      onCanvas: AppColors.dark.ink,
      onCanvasMuted: AppColors.dark.ink2,
      surface: _darkCard,
      cream: _darkRow,
      ink: AppColors.dark.ink,
      ink2: AppColors.dark.ink2,
      ink3: AppColors.dark.ink3,
      focus: AppColors.dark.ink,
      focusGap: _darkCanvas,
    );
  }
  return base.copyWith(
    canvas: _lightCanvas,
    canvasAlt: _lightCanvasAlt,
    canvasGhost: AppColors.light.canvasGhost,
    canvasGhostStrong: AppColors.light.canvasGhostStrong,
    onCanvas: AppColors.light.ink,
    onCanvasMuted: AppColors.light.ink2,
    surface: AppColors.light.surface,
    ink: AppColors.light.ink,
    ink2: AppColors.light.ink2,
    ink3: AppColors.light.ink3,
    focus: AppColors.light.ink,
    focusGap: _lightCanvas,
  );
}

/// The plain canvas with its three shapes left clear. They keep the place
/// of the standard look's shapes, so the canvas fades them out where they
/// are when this look takes over.
AmbientProfile _plainCanvas(AppColors appColors) {
  final isDark = appColors.canvas.computeLuminance() < 0.5;
  final canvas = isDark ? _darkCanvas : _lightCanvas;
  AmbientShape clear(Alignment anchor, double scale, double depth) =>
      AmbientShape(
        color: canvas,
        opacity: 0,
        anchor: anchor,
        scale: scale,
        turns: 0,
        depth: depth,
      );
  return AmbientProfile(
    canvas: canvas,
    surfaceOpacity: 1,
    shapes: List<AmbientShape>.unmodifiable([
      clear(const Alignment(0, -0.65), 0.54, 0.25),
      clear(const Alignment(-0.85, 0.35), 0.42, 0.55),
      clear(const Alignment(0.85, 0.70), 0.34, 0.85),
    ]),
  );
}

/// Minimal. It takes things away: no shapes, no pulse ring, a small face.
/// What is left is the topic and the time, large, the message and the
/// three buttons where they always are.
final AlarmStyle minimalAlarmStyle = AlarmStyle(
  id: AlarmStyleId.minimal,
  nameKey: LocaleKeys.alarm_styles_minimal,
  ringing: AlarmRingingLook(
    colors: _minimalColors,
    ambient: _plainCanvas,
    showsPulseRing: false,
    maxFace: 88,
    // Ink on the plain canvas: the strongest thing on the screen, with no
    // colour to compete with it.
    acknowledgeButton: AppButtonVariant.ink,
    // An outline shows on a plain canvas, where a wash would not.
    quietButton: AppButtonVariant.ghost,
    type: AlarmRingingType(
      // The stage word steps down to a label, and the topic takes its
      // place as the large line.
      word: const TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 1.5,
        height: 1.2,
      ),
      topic: const TextStyle(
        fontFamily: AppTypography.fontMono,
        fontFamilyFallback: AppTypography.fontMonoFallbacks,
        fontWeight: FontWeight.w700,
        fontSize: 30,
        height: 1.15,
        letterSpacing: -0.6,
      ),
      time: const TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        height: 1.2,
      ),
      messageTitle: standardRingingType.messageTitle,
      messageBody: standardRingingType.messageBody,
      messageMeta: standardRingingType.messageMeta,
    ),
  ),
  acknowledged: AlarmAcknowledgedLook(
    colors: _minimalColors,
    ambient: _plainCanvas,
    maxFace: 88,
    type: AlarmAcknowledgedType(
      title: AppTypography.display(const Color(0x00000000), fontSize: 40),
      line: standardAcknowledgedType.line,
    ),
  ),
);
