import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/standard_alarm_style.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/material.dart';

// Red Alert: a ship's bridge at battle stations. The room goes deep red,
// a rail of lights runs down each wall, and a slow bar of light sweeps
// down the room and lights the rails as it passes. The stage word is the
// largest thing after the face, and "I'm up" is the one yellow key in a
// red room.
//
// Acknowledged, the room stands down: the red goes out, the sweep stops
// and the rails hold a steady green.

/// The red room. Deeper in the dark theme, where the card is dark too.
const Color _lightRoom = Color(0xFF8C0F0C);
const Color _lightRoomAlt = Color(0xFFA51913);
const Color _darkRoom = Color(0xFF3A0706);
const Color _darkRoomAlt = Color(0xFF4C0B09);

/// The room once the alert is over.
const Color _lightStandDown = Color(0xFF221A1A);
const Color _darkStandDown = Color(0xFF120C0C);

/// The words on the room, in both themes and both stages.
const Color _onRoom = Color(0xFFFFF1EA);
const Color _onRoomMuted = Color(0xFFF0C9C1);

/// "I'm up": Crit's yellow, with ink on it.
const Color _key = Color(0xFFFFC93C);
const Color _keyHover = Color(0xFFFFD866);
const Color _onKey = Color(0xFF1A140F);

/// The outline of the ringing face. Ink, so the yellow face stands off
/// the red.
const Color _faceOutline = Color(0xFF1A0504);

// The card. Paper in the light theme, a dark console panel in the dark
// one, each with three inks.
const Color _lightCard = Color(0xFFFFEEE8);
const Color _lightRow = Color(0xFFF5DDD6);
const Color _lightInk = Color(0xFF2A0706);
const Color _lightInk2 = Color(0xFF5A1A15);
const Color _lightInk3 = Color(0xFF8A3A32);
const Color _darkCard = Color(0xFF170303);
const Color _darkStandDownCard = Color(0xFF241A1A);
const Color _darkRow = Color(0xFF30201F);
const Color _darkInk = Color(0xFFFFEDE8);
const Color _darkInk2 = Color(0xFFE5BDB6);
const Color _darkInk3 = Color(0xFFB98A83);

/// The fill of "I'm up" while the acknowledge is on its way: the key
/// with its light down.
const Color _lightBusy = Color(0xFFC9A77C);
const Color _darkBusy = Color(0xFF9A4A3E);

AppColors _roomColors(
  AppColors base, {
  required Color room,
  required Color roomAlt,
  required bool isDark,
  Color? card,
}) => base.copyWith(
  canvas: room,
  canvasAlt: roomAlt,
  canvasGhost: _onRoom.withValues(alpha: 0.10),
  // The pulse ring, and the topic pill once acknowledged.
  canvasGhostStrong: _onRoom.withValues(alpha: 0.22),
  onCanvas: _onRoom,
  onCanvasMuted: _onRoomMuted,
  surface: card ?? (isDark ? _darkCard : _lightCard),
  cream: isDark ? _darkRow : _lightRow,
  ash: isDark ? _darkBusy : _lightBusy,
  ink: isDark ? _darkInk : _lightInk,
  ink2: isDark ? _darkInk2 : _lightInk2,
  ink3: isDark ? _darkInk3 : _lightInk3,
  highlight: _key,
  highlightHover: _keyHover,
  highlightAlt: _keyHover,
  onHighlight: _onKey,
  crit: _faceOutline,
  hairline: _onRoom.withValues(alpha: 0.18),
  focus: _onRoom,
  focusGap: room,
);

/// The red room, for every severity: an alarm that rings is an alert.
AppColors _alertColors(
  AppColors base,
  SeverityMode severity,
  Brightness brightness,
) {
  final isDark = brightness == Brightness.dark;
  return _roomColors(
    base,
    room: isDark ? _darkRoom : _lightRoom,
    roomAlt: isDark ? _darkRoomAlt : _lightRoomAlt,
    isDark: isDark,
  );
}

AppColors _standDownColors(
  AppColors base,
  SeverityMode severity,
  Brightness brightness,
) {
  final isDark = brightness == Brightness.dark;
  final room = isDark ? _darkStandDown : _lightStandDown;
  return _roomColors(
    base,
    room: room,
    roomAlt: room,
    isDark: isDark,
    // One step off the dark room, so the card and "Back to topics" show.
    card: isDark ? _darkStandDownCard : null,
  );
}

/// A room with its three shapes left clear. They keep the place of the
/// standard look's shapes, so the canvas fades them out where they are
/// when this look takes over.
AmbientProfile _room(Color room) {
  AmbientShape clear(Alignment anchor, double scale, double depth) =>
      AmbientShape(
        color: room,
        opacity: 0,
        anchor: anchor,
        scale: scale,
        turns: 0,
        depth: depth,
      );
  return AmbientProfile(
    canvas: room,
    surfaceOpacity: 1,
    shapes: List<AmbientShape>.unmodifiable([
      clear(const Alignment(0, -0.65), 0.54, 0.25),
      clear(const Alignment(-0.85, 0.35), 0.42, 0.55),
      clear(const Alignment(0.85, 0.70), 0.34, 0.85),
    ]),
  );
}

AmbientProfile _alertRoom(AppColors appColors, Brightness brightness) =>
    _room(brightness == Brightness.dark ? _darkRoom : _lightRoom);

AmbientProfile _standDownRoom(AppColors appColors, Brightness brightness) =>
    _room(brightness == Brightness.dark ? _darkStandDown : _lightStandDown);

/// How long the bar of light takes to cross the room, top to bottom.
/// A point on the screen is lit once per sweep, for under a second.
const Duration redAlertSweepPeriod = Duration(milliseconds: 4200);

/// How tall the bar is, as a part of the height of the screen.
const double redAlertBarHeight = 0.22;

/// How many places a second the bar is drawn at. The background repaints
/// this often while the phone rings, and never more.
const int redAlertStepsPerSecond = 30;

/// Where the middle of the bar rests in a still frame: behind the face
/// and the stage word.
const double redAlertRestCentre = 0.30;

/// Which place of the sweep the bar is drawn at, [elapsed] into the
/// ringing stage. It goes up by one [redAlertStepsPerSecond] times a
/// second, and two frames with the same step draw the same picture.
int redAlertSweepStep(Duration elapsed) =>
    elapsed.inMicroseconds.abs() *
    redAlertStepsPerSecond ~/
    Duration.microsecondsPerSecond;

/// Where the middle of the bar is at [step], as a part of the height of
/// the screen: from just above the top edge to just below the bottom
/// one, then round again. The whole timing of this look's background.
double redAlertBarCentre(int step) {
  final stepsPerSweep =
      redAlertSweepPeriod.inMicroseconds *
      redAlertStepsPerSecond /
      Duration.microsecondsPerSecond;
  final progress = (step % stepsPerSweep) / stepsPerSweep;
  return -redAlertBarHeight / 2 + progress * (1 + redAlertBarHeight);
}

/// Whether the point [y] down the screen (0 is the top, 1 the bottom) is
/// inside the bar [elapsed] into the ringing stage.
bool redAlertIsLit(double y, Duration elapsed) =>
    (y - redAlertBarCentre(redAlertSweepStep(elapsed))).abs() <
    redAlertBarHeight / 2;

/// The light of the bar, laid on in [_barLayers] bands of this strength,
/// each shorter than the last, so the bar is brightest along its middle
/// and has a soft edge without a gradient.
const Color _barLight = Color(0xFFFF4D3D);
const double _barLayerAlpha = 0.05;
const int _barLayers = 6;

/// The rails. Red and low at rest, hot where the bar passes, and a
/// steady green once the room stands down.
const Color _rail = Color(0x73FF5A4D);
const Color _railLit = Color(0xFFFFD2C8);
const Color _railClear = Color(0xD954E08A);

/// Everything the background can put behind a word in the room, as flat
/// colours: the room, and the room under each count of layers of the bar.
/// The rails sit outside the edge of every button and every line.
List<Color> redAlertBackdropTones(AppColors colors, AlarmStage stage) {
  final tones = [colors.canvas];
  if (stage == AlarmStage.acknowledged) return tones;
  var lit = colors.canvas;
  for (var layer = 0; layer < _barLayers; layer++) {
    lit = Color.alphaBlend(_barLight.withValues(alpha: _barLayerAlpha), lit);
    tones.add(lit);
  }
  return tones;
}

/// The background of the Red Alert look: a rail of lights down each
/// side, and while the phone rings a bar of light that sweeps down the
/// room and lights the rails as it passes.
///
/// Cost: while the phone rings it repaints [redAlertStepsPerSecond] times
/// a second, and each repaint is six full-width rectangles for the bar
/// and one small rectangle per rail segment (about 50 on a phone). Still,
/// and on the acknowledged stage, it paints once and never again. It
/// allocates two `Paint`s per repaint and nothing else.
CustomPainter redAlertBackdrop(AlarmBackdropFrame frame) =>
    _RedAlertBackdropPainter(
      isStandDown: frame.stage == AlarmStage.acknowledged,
      step: frame.isStill || frame.stage == AlarmStage.acknowledged
          ? null
          : redAlertSweepStep(frame.elapsed),
    );

class _RedAlertBackdropPainter extends CustomPainter {
  const _RedAlertBackdropPainter({
    required this.isStandDown,
    required this.step,
  });

  final bool isStandDown;

  /// Where the sweep is, or null for the resting frame.
  final int? step;

  static const double _railInset = 3;
  static const double _railWidth = 6;
  static const double _segment = 26;
  static const double _segmentGap = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final step = this.step;
    final centre =
        (step == null ? redAlertRestCentre : redAlertBarCentre(step)) *
        size.height;
    final half = redAlertBarHeight * size.height / 2;

    if (!isStandDown) {
      final light = Paint()
        ..color = _barLight.withValues(alpha: _barLayerAlpha);
      for (var layer = 0; layer < _barLayers; layer++) {
        final reach = half * (1 - layer * 0.16);
        canvas.drawRect(
          Rect.fromLTRB(0, centre - reach, size.width, centre + reach),
          light,
        );
      }
    }

    final rail = Paint();
    const pitch = _segment + _segmentGap;
    for (var top = _segmentGap; top < size.height; top += pitch) {
      final middle = top + _segment / 2;
      rail.color = isStandDown
          ? _railClear
          : (middle - centre).abs() < half
          ? _railLit
          : _rail;
      canvas
        ..drawRect(
          Rect.fromLTWH(_railInset, top, _railWidth, _segment),
          rail,
        )
        ..drawRect(
          Rect.fromLTWH(
            size.width - _railInset - _railWidth,
            top,
            _railWidth,
            _segment,
          ),
          rail,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _RedAlertBackdropPainter oldDelegate) =>
      oldDelegate.step != step || oldDelegate.isStandDown != isStandDown;
}

/// Red Alert. The stage word is as large as the header's room allows,
/// and the topic and the ring time step down to console readouts under
/// it. "I'm up" is the one yellow key, and the quiet buttons are outlines.
final AlarmStyle redAlertAlarmStyle = AlarmStyle(
  id: AlarmStyleId.redAlert,
  nameKey: LocaleKeys.alarm_styles_red_alert,
  backdrop: redAlertBackdrop,
  backdropMoves: true,
  ringing: AlarmRingingLook(
    colors: _alertColors,
    ambient: _alertRoom,
    // A wash of the card would vanish into the dark room. An outline
    // shows in both themes.
    quietButton: AppButtonVariant.ghost,
    type: AlarmRingingType(
      // Larger than the standard word. The two lines under it give back
      // the height it takes, so the header is no taller.
      word: AppTypography.display(
        const Color(0x00000000),
        fontSize: 66,
      ).copyWith(height: 0.92),
      topic: const TextStyle(
        fontFamily: AppTypography.fontMono,
        fontFamilyFallback: AppTypography.fontMonoFallbacks,
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 1.3,
        letterSpacing: 1.5,
      ),
      time: const TextStyle(
        fontFamily: AppTypography.fontMono,
        fontFamilyFallback: AppTypography.fontMonoFallbacks,
        fontWeight: FontWeight.w500,
        fontSize: 13,
        height: 1.5,
        letterSpacing: 0.5,
      ),
      messageTitle: standardRingingType.messageTitle,
      messageBody: standardRingingType.messageBody,
      messageMeta: standardRingingType.messageMeta,
    ),
  ),
  acknowledged: AlarmAcknowledgedLook(
    colors: _standDownColors,
    ambient: _standDownRoom,
    type: AlarmAcknowledgedType(
      title: standardAcknowledgedType.title,
      // The body family: the hint over "At my desk" is a sentence, and in
      // the mono family it runs to a second line on a phone.
      line: standardAcknowledgedType.line,
    ),
  ),
);
