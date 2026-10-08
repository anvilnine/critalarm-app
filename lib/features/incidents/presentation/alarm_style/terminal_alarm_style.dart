import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/material.dart';

// Terminal: the alarm as a console. Near-black glass, phosphor green,
// every line in the mono family, faint scan lines, and a prompt in the
// top corner whose block cursor blinks. The yellow face is the one thing
// on the screen that is not green.
//
// A console is dark, so the look is the same in the light theme and the
// dark one.

const Color _glass = Color(0xFF050A07);
const Color _glassAlt = Color(0xFF0A130D);

/// The phosphor: the words on the glass, and the fill of "I'm up".
const Color _phosphor = Color(0xFF4DF58B);

/// The label on the green key.
const Color _onPhosphor = Color(0xFF03130A);

/// The message card and the details card: a panel one step off the glass.
const Color _panel = Color(0xFF0E2015);

/// The rows inside the details card.
const Color _panelRow = Color(0xFF153020);

/// The three greens of the text on a panel, brightest first.
const Color _bright = Color(0xFF7CFFAE);
const Color _mid = Color(0xFF4FD885);
const Color _dim = Color(0xFF47B874);

/// The fill of "I'm up" while the acknowledge is on its way: the key with
/// its light down, still the heaviest shape on the glass.
const Color _keyBusy = Color(0xFF1F6B3D);

/// The same palette on both stages, in both themes and for every
/// severity: the stage is told apart by the face and the words.
AppColors _terminalColors(
  AppColors base,
  SeverityMode severity,
  Brightness brightness,
) => base.copyWith(
  canvas: _glass,
  canvasAlt: _glassAlt,
  canvasGhost: _phosphor.withValues(alpha: 0.10),
  // The pulse ring, and the topic pill once acknowledged.
  canvasGhostStrong: _phosphor.withValues(alpha: 0.22),
  onCanvas: _phosphor,
  onCanvasMuted: _mid,
  surface: _panel,
  cream: _panelRow,
  ash: _keyBusy,
  ink: _bright,
  ink2: _mid,
  ink3: _dim,
  highlight: _phosphor,
  highlightHover: _bright,
  highlightAlt: _bright,
  onHighlight: _onPhosphor,
  // The outline of the ringing face, and what it throws off.
  crit: _phosphor,
  hairline: _phosphor.withValues(alpha: 0.18),
  focus: _bright,
  focusGap: _glass,
);

/// The glass, with its three shapes left clear. They keep the place of
/// the standard look's shapes, so the canvas fades them out where they
/// are when this look takes over.
AmbientProfile _glassCanvas(AppColors appColors, Brightness brightness) {
  AmbientShape clear(Alignment anchor, double scale, double depth) =>
      AmbientShape(
        color: _glass,
        opacity: 0,
        anchor: anchor,
        scale: scale,
        turns: 0,
        depth: depth,
      );
  return AmbientProfile(
    canvas: _glass,
    surfaceOpacity: 1,
    shapes: List<AmbientShape>.unmodifiable([
      clear(const Alignment(0, -0.65), 0.54, 0.25),
      clear(const Alignment(-0.85, 0.35), 0.42, 0.55),
      clear(const Alignment(0.85, 0.70), 0.34, 0.85),
    ]),
  );
}

/// One blink of the cursor: on for [terminalCursorOnFor], then off for
/// the rest. Two changes in 1.2 seconds, well under three a second.
const Duration terminalBlinkPeriod = Duration(milliseconds: 1200);
const Duration terminalCursorOnFor = Duration(milliseconds: 700);

/// Whether the block cursor is drawn [elapsed] into the stage. The whole
/// timing of this look's background: a still frame has the cursor on.
bool terminalCursorIsOn(Duration elapsed, {required bool isStill}) {
  if (isStill) return true;
  final into =
      elapsed.inMicroseconds.abs() % terminalBlinkPeriod.inMicroseconds;
  return into < terminalCursorOnFor.inMicroseconds;
}

/// How strong a scan line is over the glass.
const double _scanLineAlpha = 0.05;

/// One scan line every this many logical pixels.
const double _scanLinePitch = 4;

/// Everything the background can put behind a word on the glass, as flat
/// colours: the glass itself and a scan line over it. The prompt sits in
/// the top corner, clear of every line of text.
List<Color> terminalBackdropTones(AppColors colors) => [
  colors.canvas,
  Color.alphaBlend(
    colors.onCanvas.withValues(alpha: _scanLineAlpha),
    colors.canvas,
  ),
];

/// The background of the Terminal look: scan lines over the whole glass,
/// and a prompt with a block cursor in the top corner.
///
/// The prompt is drawn at a fixed place under the status bar, left of the
/// face and above the first line of text on every phone, because a
/// background is not told where anything else sits.
///
/// Cost: it repaints only when the cursor changes, twice in 1.2 seconds,
/// and never while still. One repaint is a 1 pixel rectangle per scan
/// line (211 on a phone 844 high), two strokes and one rectangle. It
/// allocates two `Paint`s and nothing else.
CustomPainter terminalBackdrop(AlarmBackdropFrame frame) =>
    _TerminalBackdropPainter(
      phosphor: frame.colors.onCanvas,
      isCursorOn: terminalCursorIsOn(frame.elapsed, isStill: frame.isStill),
    );

class _TerminalBackdropPainter extends CustomPainter {
  const _TerminalBackdropPainter({
    required this.phosphor,
    required this.isCursorOn,
  });

  final Color phosphor;
  final bool isCursorOn;

  // The prompt: a chevron, then the cursor one cell to its right.
  static const double _promptLeft = 18;
  static const double _promptTop = 64;
  static const double _cellWidth = 12;
  static const double _cellHeight = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = phosphor.withValues(alpha: _scanLineAlpha);
    for (var y = 0.0; y < size.height; y += _scanLinePitch) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }

    final stroke = Paint()
      ..color = phosphor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    const middle = _promptTop + _cellHeight / 2;
    const tip = Offset(_promptLeft + _cellWidth - 2, middle);
    canvas
      ..drawLine(const Offset(_promptLeft + 1, _promptTop + 4), tip, stroke)
      ..drawLine(
        tip,
        const Offset(_promptLeft + 1, _promptTop + _cellHeight - 4),
        stroke,
      );
    if (!isCursorOn) return;
    canvas.drawRect(
      const Rect.fromLTWH(
        _promptLeft + _cellWidth + 8,
        _promptTop,
        _cellWidth,
        _cellHeight,
      ),
      stroke..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _TerminalBackdropPainter oldDelegate) =>
      oldDelegate.isCursorOn != isCursorOn || oldDelegate.phosphor != phosphor;
}

TextStyle _mono(
  double size,
  FontWeight weight, {
  required double height,
  double letterSpacing = 0,
}) => TextStyle(
  fontFamily: AppTypography.fontMono,
  fontFamilyFallback: AppTypography.fontMonoFallbacks,
  fontWeight: weight,
  fontSize: size,
  height: height,
  letterSpacing: letterSpacing,
);

/// Terminal. Every line is in the mono family, green on near-black, with
/// a small face so the screen reads as a console first. "I'm up" is the
/// one solid green key, and the two quiet buttons are outlined keys.
final AlarmStyle terminalAlarmStyle = AlarmStyle(
  id: AlarmStyleId.terminal,
  nameKey: LocaleKeys.alarm_styles_terminal,
  backdrop: terminalBackdrop,
  backdropMoves: true,
  ringing: AlarmRingingLook(
    colors: _terminalColors,
    ambient: _glassCanvas,
    maxFace: 132,
    // An outline shows on the dark glass, where a wash of the panel
    // would not.
    quietButton: AppButtonVariant.ghost,
    type: AlarmRingingType(
      word: _mono(36, FontWeight.w700, height: 1.15, letterSpacing: 2),
      topic: _mono(20, FontWeight.w700, height: 1.3),
      time: _mono(14, FontWeight.w500, height: 1.5),
      messageTitle: _mono(17, FontWeight.w700, height: 1.3),
      messageBody: _mono(13, FontWeight.w500, height: 1.45),
      messageMeta: _mono(12, FontWeight.w500, height: 1.4),
    ),
  ),
  acknowledged: AlarmAcknowledgedLook(
    colors: _terminalColors,
    ambient: _glassCanvas,
    maxFace: 132,
    type: AlarmAcknowledgedType(
      title: _mono(34, FontWeight.w700, height: 1.15),
      // Small enough for the hint over "At my desk" to stay on one line
      // on a phone 375 wide.
      line: _mono(12, FontWeight.w500, height: 1.5, letterSpacing: -0.2),
    ),
  ),
);
