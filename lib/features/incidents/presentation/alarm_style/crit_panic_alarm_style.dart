import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/material.dart';

// Crit Panic: Crit's own look, turned up. The canvas is his yellow, with
// rays bursting out from behind the face and a few sparks beside it, and
// on every ring the burst jolts. Everything drawn on it is ink: the face
// outline, the pulse ring, the word, the outlined buttons, and "I'm up"
// as one solid ink pill.
//
// Acknowledged, the panic is over: the canvas turns Crit's cobalt, the
// burst holds still and the yellow face is the bright thing on it.

const Color _yellow = Color(0xFFFFC93C);
const Color _yellowRay = Color(0xFFFFDA6E);
const Color _ink = Color(0xFF1A140F);
const Color _paper = Color(0xFFFFFFFF);

/// The calm canvas, its rays and its sparks, per theme.
const Color _lightCalm = Color(0xFF2A3BD8);
const Color _lightCalmRay = Color(0xFF3E4FE6);
const Color _lightCalmSpark = Color(0xFF4F60F0);
const Color _darkCalm = Color(0xFF141A4A);
const Color _darkCalmRay = Color(0xFF1B2260);
const Color _darkCalmSpark = Color(0xFF263080);

const Color _onCalm = Color(0xFFFFFFFF);
const Color _onDarkCalm = Color(0xFFF7F1EA);

/// The dark theme's card: an ink panel on the yellow, with cream words.
const Color _darkCardInk = Color(0xFFF7F1EA);
const Color _darkCardInk2 = Color(0xFFCBBDAF);
const Color _darkCardInk3 = Color(0xFF9A8877);

/// The faint label of a details row in the dark theme, light enough to
/// read on its inset row.
const Color _darkRowLabel = Color(0xFFB5A493);

/// The fill of "I'm up" while the acknowledge is on its way: a deep
/// amber under the dark spinner of the light theme, a dark brown under
/// the pale one of the dark theme.
const Color _lightBusy = Color(0xFFB8892A);
const Color _darkBusy = Color(0xFF4A3A22);

/// Yellow and ink, for every severity. The dark theme changes the card
/// and nothing else.
AppColors _panicColors(
  AppColors base,
  SeverityMode severity,
  Brightness brightness,
) {
  final isDark = brightness == Brightness.dark;
  return base.copyWith(
    canvas: _yellow,
    canvasAlt: _yellowRay,
    canvasGhost: _ink.withValues(alpha: 0.07),
    // The pulse ring: ink, nearly solid.
    canvasGhostStrong: _ink.withValues(alpha: 0.85),
    onCanvas: _ink,
    onCanvasMuted: AppColors.light.onCanvasMuted,
    surface: isDark ? _ink : _paper,
    cream: isDark ? AppColors.dark.cream : AppColors.light.cream,
    ash: isDark ? _darkBusy : _lightBusy,
    ink: isDark ? _darkCardInk : _ink,
    ink2: isDark ? _darkCardInk2 : AppColors.light.ink2,
    ink3: isDark ? _darkCardInk3 : AppColors.light.ink3,
    // "I'm up": a solid ink pill with a yellow label, in both themes.
    panel: _ink,
    onPanel: _yellow,
    // The outline of the ringing face, and what it throws off.
    crit: _ink,
    hairline: _ink.withValues(alpha: 0.14),
    focus: _ink,
    focusGap: _yellow,
  );
}

AppColors _calmColors(
  AppColors base,
  SeverityMode severity,
  Brightness brightness,
) {
  if (brightness == Brightness.dark) {
    return base.copyWith(
      canvas: _darkCalm,
      canvasAlt: _darkCalmRay,
      canvasGhost: AppColors.dark.ackGhost,
      canvasGhostStrong: AppColors.dark.ackGhostStrong,
      onCanvas: _onDarkCalm,
      onCanvasMuted: AppColors.dark.ackTextMuted,
      surface: AppColors.dark.surface,
      cream: AppColors.dark.cream,
      ash: AppColors.dark.ash,
      ink: AppColors.dark.ink,
      ink2: AppColors.dark.ink2,
      ink3: _darkRowLabel,
      focus: _onDarkCalm,
      focusGap: _darkCalm,
    );
  }
  return base.copyWith(
    canvas: _lightCalm,
    canvasAlt: _lightCalmRay,
    canvasGhost: AppColors.light.ackGhost,
    canvasGhostStrong: AppColors.light.ackGhostStrong,
    onCanvas: _onCalm,
    onCanvasMuted: AppColors.light.ackTextMuted,
    surface: _paper,
    cream: AppColors.light.cream,
    ash: AppColors.light.ash,
    ink: _ink,
    ink2: AppColors.light.ink2,
    ink3: AppColors.light.ink3,
    focus: _onCalm,
    focusGap: _lightCalm,
  );
}

/// A canvas with its three shapes left clear: the burst is the picture,
/// and it is painted by [critPanicBackdrop]. The shapes keep the place of
/// the standard look's, so the canvas fades them out where they are.
AmbientProfile _plain(Color canvas) {
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

AmbientProfile _panicCanvas(AppColors appColors, Brightness brightness) =>
    _plain(_yellow);

AmbientProfile _calmCanvas(AppColors appColors, Brightness brightness) =>
    _plain(brightness == Brightness.dark ? _darkCalm : _lightCalm);

/// One beat: the burst jolts once per ring of the pulse ring.
const Duration critPanicBeat = AppDurations.ring;

/// How long a jolt lasts. The rest of the beat the burst is at rest and
/// nothing is repainted.
const Duration critPanicJoltFor = Duration(milliseconds: 220);

/// How far the burst is thrown [elapsed] into the ringing stage: 1 at the
/// start of a beat, easing back to 0 within [critPanicJoltFor] and 0 for
/// the rest of the beat. The whole timing of this look's background: a
/// still frame is 0, the burst at rest.
double critPanicKick(Duration elapsed, {required bool isStill}) {
  if (isStill) return 0;
  final into = elapsed.inMicroseconds.abs() % critPanicBeat.inMicroseconds;
  if (into >= critPanicJoltFor.inMicroseconds) return 0;
  final left = 1 - into / critPanicJoltFor.inMicroseconds;
  return left * left * left;
}

/// The colour of the sparks on [canvas].
Color _sparkOn(Color canvas) {
  if (canvas == _lightCalm) return _lightCalmSpark;
  if (canvas == _darkCalm) return _darkCalmSpark;
  return _paper;
}

/// Everything the background can put behind a word, as flat colours: the
/// canvas, a ray and a spark.
List<Color> critPanicBackdropTones(AppColors colors) => [
  colors.canvas,
  colors.canvasAlt,
  _sparkOn(colors.canvas),
];

/// Twelve rays from the origin out to a circle of radius 1, each 15
/// degrees wide with 15 degrees between two, one pointing straight up.
/// Built once and scaled to the screen by the canvas.
final Path _rays = () {
  const wedge = math.pi / 12;
  final path = Path();
  for (var ray = 0; ray < 12; ray++) {
    final from = -math.pi / 2 - wedge / 2 + ray * 2 * wedge;
    path
      ..moveTo(0, 0)
      ..lineTo(math.cos(from), math.sin(from))
      ..lineTo(math.cos(from + wedge), math.sin(from + wedge))
      ..close();
  }
  return path;
}();

/// A four-point spark that fits a circle of radius 1. Built once.
final Path _spark = () {
  const waist = 0.2;
  return Path()
    ..moveTo(0, -1)
    ..lineTo(waist, -waist)
    ..lineTo(1, 0)
    ..lineTo(waist, waist)
    ..lineTo(0, 1)
    ..lineTo(-waist, waist)
    ..lineTo(-1, 0)
    ..lineTo(-waist, -waist)
    ..close();
}();

/// Where the sparks sit, as parts of the width and the height of the
/// screen, and how large each is as a part of its shorter side. All four are
/// in the top corners and beside the face, off the middle of the screen
/// where the words are.
const List<(double, double, double)> _sparks = [
  (0.10, 0.085, 0.050),
  (0.90, 0.110, 0.034),
  (0.07, 0.370, 0.030),
  (0.93, 0.340, 0.044),
];

/// The background of the Crit Panic look: rays that burst from behind
/// the face to the edges of the screen, and four sparks. While the phone
/// rings the burst jolts once a beat: the rays are thrown a few degrees
/// round and the sparks swell, then both ease back to rest.
///
/// It is drawn in fills only, in colours ink reads on, because a
/// background is not told where the words sit.
///
/// Cost: it repaints only during a jolt, [critPanicJoltFor] out of every
/// [critPanicBeat], and never while still or acknowledged. One repaint is
/// five filled paths that were built once, each drawn through a canvas
/// transform. It allocates one `Paint` per repaint and nothing else.
CustomPainter critPanicBackdrop(AlarmBackdropFrame frame) =>
    _CritPanicBackdropPainter(
      ray: frame.colors.canvasAlt,
      spark: _sparkOn(frame.colors.canvas),
      kick: frame.stage == AlarmStage.acknowledged
          ? 0
          : critPanicKick(frame.elapsed, isStill: frame.isStill),
    );

class _CritPanicBackdropPainter extends CustomPainter {
  const _CritPanicBackdropPainter({
    required this.ray,
    required this.spark,
    required this.kick,
  });

  final Color ray;
  final Color spark;
  final double kick;

  /// Where the burst comes from, down the screen: about the middle of the
  /// face on an upright phone.
  static const double _centreY = 0.23;

  /// How far round a jolt throws the rays: 6 degrees, under half a ray,
  /// so a ray never lands where its neighbour was.
  static const double _throw = math.pi / 30;

  /// How much a jolt swells the sparks.
  static const double _swell = 0.4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ray;
    final centre = Offset(size.width / 2, size.height * _centreY);
    // Far enough to pass the furthest corner, thrown or not.
    final reach = 1.1 * (Offset(0, size.height) - centre).distance;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(kick * _throw)
      ..scale(reach)
      ..drawPath(_rays, paint)
      ..restore();

    paint.color = spark;
    for (final (x, y, radius) in _sparks) {
      canvas
        ..save()
        ..translate(size.width * x, size.height * y)
        ..scale(size.shortestSide * radius * (1 + kick * _swell))
        ..drawPath(_spark, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CritPanicBackdropPainter oldDelegate) =>
      oldDelegate.kick != kick ||
      oldDelegate.ray != ray ||
      oldDelegate.spark != spark;
}

/// Crit Panic. The face is as large as the layout allows, the pulse ring
/// is ink, and the word is larger than the standard one. "I'm up" is the
/// solid ink pill and the quiet buttons are ink outlines.
final AlarmStyle critPanicAlarmStyle = AlarmStyle(
  id: AlarmStyleId.critPanic,
  nameKey: LocaleKeys.alarm_styles_crit_panic,
  backdrop: critPanicBackdrop,
  backdropMoves: true,
  ringing: AlarmRingingLook(
    colors: _panicColors,
    ambient: _panicCanvas,
    // Ink with a yellow label, whatever the card's inks are.
    acknowledgeButton: AppButtonVariant.crit,
    // An ink outline, where a white wash would vanish over a ray.
    quietButton: AppButtonVariant.ghost,
    type: AlarmRingingType(
      // Larger than the standard word. The ring time gives back the
      // height it takes, so the header is no taller.
      word: AppTypography.display(
        const Color(0x00000000),
        fontSize: 64,
      ).copyWith(height: 0.92),
      topic: const TextStyle(
        fontFamily: AppTypography.fontMono,
        fontFamilyFallback: AppTypography.fontMonoFallbacks,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.3,
      ),
      time: const TextStyle(
        fontFamily: AppTypography.fontBody,
        fontFamilyFallback: AppTypography.fontBodyFallbacks,
        fontWeight: FontWeight.w700,
        fontSize: 15,
        height: 1.25,
      ),
      messageTitle: standardRingingType.messageTitle,
      messageBody: standardRingingType.messageBody,
      messageMeta: standardRingingType.messageMeta,
    ),
  ),
  acknowledged: AlarmAcknowledgedLook(
    colors: _calmColors,
    ambient: _calmCanvas,
    type: standardAcknowledgedType,
  ),
);
