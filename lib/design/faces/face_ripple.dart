import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Ink for the bright crowd heads, the same in light and dark mode.
const Color faceCrowdInk = Color(0xFF1A140F);

/// Bright heads for the crowd animations. Dark ink on all of them, so they
/// read the same in light and dark mode.
const List<Color> faceCrowdFills = [
  Color(0xFFFFC93C),
  Color(0xFF4EAAD8),
  Color(0xFFE2673D),
  Color(0xFF3FA652),
  Color(0xFFF2A7C3),
];

final Map<FaceState, FaceShape> _shapes = {};

FaceShape _shape(FaceState state) =>
    _shapes.putIfAbsent(state, () => faceFor(state));

double _window(double t, double start, double length) =>
    ((t - start) / length).clamp(0.0, 1.0);

FaceShape _blend(FaceState a, FaceState b, double p) => FaceShape.lerp(
  _shape(a),
  _shape(b),
  Curves.easeInOutCubic.transform(p),
);

FaceShape _withBlink(FaceShape face, double t, {double offset = 0}) {
  final local = (t + offset) % 3.7;
  return local < 0.12 ? face.blinking : face;
}

Widget _face(FaceShape shape, double size, {Color? fill}) => FaceWidget(
  state: FaceState.calm,
  shape: shape,
  size: size,
  overrideFillColor: fill,
  overrideStrokeColor: fill == null ? null : faceCrowdInk,
  overrideInkColor: fill == null ? null : faceCrowdInk,
);

/// Every face there is, bar the blink, which is a moment rather than a
/// face. What the welcome screen's ripple picks from.
final List<FaceState> allRippleFaces = List.unmodifiable([
  for (final f in FaceState.values)
    if (f != FaceState.blink) f,
]);

/// The faces for a celebration: nothing alarmed, angry, worried or sad.
/// `content` is left out because the festive ripple rests on it.
const List<FaceState> happyRippleFaces = [
  FaceState.laughing,
  FaceState.happy,
  FaceState.success,
  FaceState.surprised,
  FaceState.curious,
];

/// A mixed wall for a full celebration: eight glad faces, one per head in
/// turn, so no two neighbours in a row of four match.
const List<FaceState> celebrationRestFaces = [
  FaceState.happy,
  FaceState.content,
  FaceState.laughing,
  FaceState.love,
  FaceState.proud,
  FaceState.cheeky,
  FaceState.calm,
  FaceState.success,
];

/// A calmer mixed wall, for good news that is only part of the story.
const List<FaceState> quietRestFaces = [
  FaceState.content,
  FaceState.calm,
  FaceState.happy,
];

/// Which of [pool] a cell shows for [wave]. Without [random] the faces run
/// in order, so two waves show every face there is (the welcome screen).
/// With it each cell and wave gets its own pick, never the same face twice
/// in a row on one cell.
@visibleForTesting
FaceState pickRippleFace(
  List<FaceState> pool, {
  required int wave,
  required int cell,
  required int cellCount,
  bool random = false,
}) {
  final w = math.max(wave, 0);
  if (!random) return pool[(w * cellCount + cell) % pool.length];
  int index(int wv) {
    // Two rounds of MINSTD. Small enough to stay exact on the web.
    var h = (wv * 7919 + cell * 104729 + 12345) % 2147483647;
    h = (h * 48271) % 2147483647;
    h = (h * 48271) % 2147483647;
    return h % pool.length;
  }

  // Walk the waves so a nudged pick is what the next wave compares with.
  var shown = index(0);
  for (var k = 1; k <= w; k++) {
    final next = index(k);
    shown = next == shown && pool.length > 1 ? (next + 1) % pool.length : next;
  }
  return pool[shown];
}

/// The face head [cell] rests on between waves: its own entry of
/// [restFaces] when there are any, else [restFace].
@visibleForTesting
FaceState rippleRestFace({
  required int cell,
  required FaceState restFace,
  List<FaceState>? restFaces,
}) => restFaces == null || restFaces.isEmpty
    ? restFace
    : restFaces[cell % restFaces.length];

/// The grid for a box: the head size and how many rows and columns fit.
/// Always four columns and up to five rows, sized by the tighter of width
/// and height.
@visibleForTesting
({double size, int rows, int cols}) rippleGrid(
  double width,
  double height, {
  double gap = 12,
}) {
  const cols = 4;
  final size = math.min(
    (width - gap * (cols - 1)) / cols,
    (height - gap * 4) / 5,
  );
  final rows = size <= 0
      ? 0
      : ((height + gap) / (size + gap)).floor().clamp(1, 5);
  return (size: size, rows: rows, cols: cols);
}

/// A grid of faces in every colour, flipping over in waves. The welcome
/// screen's "Ripple" hero (every face) and the picture on the test alarm's
/// acknowledged screen (happy faces only). It fills the box it is given.
/// With animations switched off it sits still on a settled frame.
///
/// The defaults are the welcome screen's: every face, calm between waves,
/// four columns, faces in a fixed order.
class FaceRipple extends StatefulWidget {
  const FaceRipple({
    this.faces,
    this.restFace = FaceState.calm,
    this.restFaces,
    this.randomFaces = false,
    super.key,
  });

  /// What the waves pick from. Null means [allRippleFaces].
  final List<FaceState>? faces;

  /// The face each head settles back to between waves.
  final FaceState restFace;

  /// A different rest face per head: cell `i` settles on
  /// `restFaces[i % length]`, so the wall is mixed and the same from frame
  /// to frame. Null or empty means every head rests on [restFace].
  final List<FaceState>? restFaces;

  /// Pick a face per cell and wave at random (a fixed shuffle, so a frame is
  /// repeatable) instead of running through [faces] in order.
  final bool randomFaces;

  @override
  State<FaceRipple> createState() => _FaceRippleState();
}

class _FaceRippleState extends State<FaceRipple>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _seconds = 0;

  /// Where a still ripple rests: after the first wave has landed.
  static const double restAt = 1.2;

  double get t => (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
      ? restAt
      : _seconds;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => setState(() => _seconds = elapsed.inMicroseconds / 1e6),
    );
    unawaited(_ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  static const double _firstWave = 1.2;
  static const double _period = 3.2;

  @override
  Widget build(BuildContext context) {
    final t = this.t;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 12.0;
        final (:size, :rows, :cols) = rippleGrid(
          box.maxWidth,
          box.maxHeight,
        );
        if (rows == 0) return const SizedBox.shrink();
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows; r++)
                Padding(
                  padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var c = 0; c < cols; c++) ...[
                        if (c > 0) const SizedBox(width: gap),
                        _cell(r, c, rows, cols, size, t),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// How far wave [k] has to travel to reach the cell: it sweeps down the
  /// diagonal, then bursts out from the middle, then comes back from the
  /// far corner, and round again.
  static double _reach(int k, int r, int c, int rows, int cols) => switch (k %
      3) {
    0 => (r + c).toDouble(),
    1 =>
      math.sqrt(
            math.pow(r - (rows - 1) / 2, 2) + math.pow(c - (cols - 1) / 2, 2),
          ) *
          1.6,
    _ => ((rows - 1 - r) + (cols - 1 - c)).toDouble(),
  };

  Widget _cell(int r, int c, int rows, int cols, double size, double t) {
    final cell = r * cols + c;
    final pop = Curves.easeOutBack.transform(
      _window(t, (r + c) * 0.07, 0.5),
    );

    // The latest wave to have reached this cell, and how long ago.
    var wave = -1;
    var local = 0.0;
    if (t >= _firstWave) {
      for (var k = ((t - _firstWave) / _period).floor(); k >= 0; k--) {
        final arrived =
            _firstWave + k * _period + _reach(k, r, c, rows, cols) * 0.16;
        if (t >= arrived) {
          wave = k;
          local = t - arrived;
          break;
        }
      }
    }

    // Each wave flips the face over like a card: a new colour on the back
    // and a new face, which it holds, then settles back to calm. Two waves
    // show every face there is.
    final fillBefore =
        faceCrowdFills[(cell + math.max<int>(wave, 0)) % faceCrowdFills.length];
    final fillAfter = faceCrowdFills[(cell + wave + 1) % faceCrowdFills.length];
    final reaction = pickRippleFace(
      widget.faces ?? allRippleFaces,
      wave: wave,
      cell: cell,
      cellCount: rows * cols,
      random: widget.randomFaces,
    );
    final rest = rippleRestFace(
      cell: cell,
      restFace: widget.restFace,
      restFaces: widget.restFaces,
    );

    FaceShape face;
    var flip = 0.0;
    var bump = 0.0;
    var fill = wave < 0
        ? faceCrowdFills[cell % faceCrowdFills.length]
        : fillAfter;
    if (wave < 0 || local > 1.7) {
      face = _withBlink(_shape(rest), t, offset: cell * 0.37);
    } else if (local < 0.4) {
      flip = local / 0.4;
      final halfway = flip >= 0.5;
      if (!halfway) fill = fillBefore;
      face = halfway ? _shape(reaction) : _shape(rest);
      bump = math.sin(flip * math.pi) * 0.18;
    } else if (local < 1.3) {
      face = _shape(reaction);
    } else {
      face = _blend(reaction, rest, (local - 1.3) / 0.4);
    }

    // Flip on the axis the wave is travelling along, so it reads as a
    // wave rolling across.
    final angle = math.sin(flip * math.pi) * math.pi / 2 * 0.98;
    final transform = Matrix4.identity()..setEntry(3, 2, 0.002);
    if (wave % 3 == 1) {
      transform.rotateX(angle);
    } else {
      transform.rotateY(wave % 3 == 0 ? angle : -angle);
    }
    final hop = -math.sin(flip * math.pi) * size * 0.18;

    return Transform.translate(
      offset: Offset(0, hop),
      child: Transform(
        alignment: Alignment.center,
        transform: transform,
        child: Transform.scale(
          scale: pop + bump,
          child: _face(face, size, fill: fill),
        ),
      ),
    );
  }
}
