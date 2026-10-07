import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/limits_preview_clock.dart';
import 'package:flutter/material.dart';

// Critical topics: a Critical switch is tapped, will not go on, and then
// does. It rests switched on.

/// Where the switch is in its loop, in the order it happens.
enum TopicsPreviewPhase {
  /// Switched on. The resting picture.
  on,

  /// Sliding back off, to play again.
  resetting,

  /// Off, waiting for the tap.
  off,

  /// Tapped: the knob starts over, comes back, and the switch shakes.
  refusing,

  /// Off again after the refusal.
  refused,

  /// Tapped again, and this time it goes on.
  turningOn,
}

/// The seconds of the loop at which each phase starts.
abstract final class TopicsPreviewTimes {
  static const double reset = 0.6;
  static const double off = 0.85;
  static const double firstTap = 1.25;
  static const double refused = 1.75;
  static const double secondTap = 2.45;
  static const double on = 2.75;

  /// The next topic in the list follows the first one on.
  static const double followerTap = 2.85;
  static const double followerOn = 3.1;
}

/// Everything the switch picture needs at one moment.
@immutable
class TopicsPreviewFrame {
  const TopicsPreviewFrame({
    required this.phase,
    required this.knob,
    required this.track,
    required this.shake,
    required this.tapOpacity,
    required this.tapScale,
    required this.follower,
  });

  final TopicsPreviewPhase phase;

  /// Where the knob is: 0 off, 1 on. It runs a little past 1 as it lands.
  final double knob;

  /// How far the track colour is from off (0) to on (1).
  final double track;

  /// Sideways push of the whole switch, from -1 to 1. Zero at rest.
  final double shake;

  /// The tap mark over the knob.
  final double tapOpacity;
  final double tapScale;

  /// The next topic's switch, 0 off to 1 on.
  final double follower;

  /// True from the refusal until the switch goes on.
  bool get isRefused =>
      phase == TopicsPreviewPhase.refusing ||
      phase == TopicsPreviewPhase.refused;

  bool get isOn =>
      phase == TopicsPreviewPhase.on || phase == TopicsPreviewPhase.turningOn;

  @override
  bool operator ==(Object other) =>
      other is TopicsPreviewFrame &&
      other.phase == phase &&
      other.knob == knob &&
      other.track == track &&
      other.shake == shake &&
      other.tapOpacity == tapOpacity &&
      other.tapScale == tapScale &&
      other.follower == follower;

  @override
  int get hashCode =>
      Object.hash(phase, knob, track, shake, tapOpacity, tapScale, follower);
}

/// The phase at clock second [t].
TopicsPreviewPhase topicsPreviewPhaseAt(double t) {
  final u = loopT(t, limitsPreviewPeriod);
  if (u < TopicsPreviewTimes.reset) return TopicsPreviewPhase.on;
  if (u < TopicsPreviewTimes.off) return TopicsPreviewPhase.resetting;
  if (u < TopicsPreviewTimes.firstTap) return TopicsPreviewPhase.off;
  if (u < TopicsPreviewTimes.refused) return TopicsPreviewPhase.refusing;
  if (u < TopicsPreviewTimes.secondTap) return TopicsPreviewPhase.refused;
  if (u < TopicsPreviewTimes.on) return TopicsPreviewPhase.turningOn;
  return TopicsPreviewPhase.on;
}

/// A tap mark that closes in on [at], lands, and fades.
(double opacity, double scale) _tap(double u, double at) {
  if (u < at - 0.26 || u > at + 0.22) return (0, 1);
  if (u <= at) {
    final p = AppCurves.easeOut.transform(phase(u, at - 0.26, at));
    return (p, 1.8 - 0.8 * p);
  }
  final p = phase(u, at, at + 0.22);
  return (1 - p, 1 - 0.2 * p);
}

/// The switch at clock second [t]. The loop starts and ends switched on.
TopicsPreviewFrame topicsPreviewFrameAt(double t) {
  final u = loopT(t, limitsPreviewPeriod);
  final at = topicsPreviewPhaseAt(t);

  const tap1 = TopicsPreviewTimes.firstTap;
  final back = AppCurves.easeOut.transform(
    phase(u, TopicsPreviewTimes.reset, TopicsPreviewTimes.off),
  );

  final (double knob, double track) = switch (at) {
    TopicsPreviewPhase.on => (1.0, 1.0),
    TopicsPreviewPhase.resetting => (1 - back, 1 - back),
    TopicsPreviewPhase.off || TopicsPreviewPhase.refused => (0.0, 0.0),
    // Half way over, then straight back.
    TopicsPreviewPhase.refusing => (
      u < tap1 + 0.12
          ? 0.5 * AppCurves.easeSpring.transform(phase(u, tap1, tap1 + 0.12))
          : 0.5 *
                (1 -
                    AppCurves.easeOut.transform(
                      phase(u, tap1 + 0.12, tap1 + 0.4),
                    )),
      0.0,
    ),
    TopicsPreviewPhase.turningOn => (
      AppCurves.easeSpring.transform(
        phase(
          u,
          TopicsPreviewTimes.secondTap,
          TopicsPreviewTimes.secondTap + 0.25,
        ),
      ),
      phase(
        u,
        TopicsPreviewTimes.secondTap,
        TopicsPreviewTimes.secondTap + 0.15,
      ),
    ),
  };

  final shake = at == TopicsPreviewPhase.refusing
      ? limitsKeyframes(u, const [
          (tap1 + 0.09, 0.0),
          (tap1 + 0.15, -1.0),
          (tap1 + 0.23, 1.0),
          (tap1 + 0.31, -0.6),
          (tap1 + 0.39, 0.0),
        ])
      : 0.0;

  final first = _tap(u, TopicsPreviewTimes.firstTap);
  final second = _tap(u, TopicsPreviewTimes.secondTap);
  final tap = first.$1 > 0 ? first : second;

  final double follower;
  if (u < TopicsPreviewTimes.reset || u >= TopicsPreviewTimes.followerOn) {
    follower = 1;
  } else if (u < TopicsPreviewTimes.off) {
    follower = 1 - back;
  } else {
    follower = AppCurves.easeSpring.transform(
      phase(
        u,
        TopicsPreviewTimes.followerTap,
        TopicsPreviewTimes.followerOn,
      ),
    );
  }

  return TopicsPreviewFrame(
    phase: at,
    knob: knob,
    track: track,
    shake: shake,
    tapOpacity: tap.$1,
    tapScale: tap.$2,
    follower: follower,
  );
}

/// How the picture is laid out in a box: the switch alone when the box is
/// small, and a short list of topics with the switch on one of them when
/// there is room.
@immutable
class TopicsPreviewLayout {
  const TopicsPreviewLayout({
    required this.rows,
    required this.rowHeight,
    required this.padding,
    required this.switchHeight,
    required this.nameSize,
  });

  /// Width over height of the switch, as the app's own switch has it.
  static const double switchAspect = 48 / 28;

  /// Topics listed. Zero is the switch alone.
  final int rows;
  final double rowHeight;
  final double padding;
  final double switchHeight;

  /// Type size of a topic name. Zero draws a bar in its place.
  final double nameSize;

  bool get isSwitchAlone => rows == 0;
  bool get showsNames => nameSize > 0;
  double get switchWidth => switchHeight * switchAspect;
  double get faceSize => rowHeight * 0.62;
  double get gap => rowHeight * 0.18;

  /// Which row holds the switch that is tapped.
  int get tappedRow => math.min(rows, 3) - 1;
}

/// The longest topic name, in characters, with a little air.
const double _nameChars = 6.7;

TopicsPreviewLayout topicsPreviewLayoutFor(Size size) {
  final w = size.width;
  final h = size.height;

  if (size.shortestSide < limitsPreviewSmallEdge) {
    final switchWidth = math.min(
      w * 0.62,
      h * 0.62 * TopicsPreviewLayout.switchAspect,
    );
    return TopicsPreviewLayout(
      rows: 0,
      rowHeight: h,
      padding: 0,
      switchHeight: switchWidth / TopicsPreviewLayout.switchAspect,
      nameSize: 0,
    );
  }

  final padding = size.shortestSide * 0.08;
  final ideal = (w * 0.26).clamp(30.0, 64.0);
  final room = h - 2 * padding;
  final rows = (room / ideal).floor().clamp(1, 4);
  final rowHeight = math.min(room / rows, ideal * 1.2);
  final switchHeight = rowHeight * 0.46;
  final nameRoom =
      w -
      2 * padding -
      rowHeight * 0.62 -
      switchHeight * TopicsPreviewLayout.switchAspect -
      2 * rowHeight * 0.18;
  final nameSize = math.min(rowHeight * 0.23, nameRoom / _nameChars);

  return TopicsPreviewLayout(
    rows: rows,
    rowHeight: rowHeight,
    padding: padding,
    switchHeight: switchHeight,
    nameSize: nameSize >= limitsPreviewMinType ? nameSize : 0,
  );
}

/// The topics a list of [rows] shows, ending on the ones being switched.
List<String> topicsPreviewNames(int rows) {
  const all = ['prod-db', 'uptime-kuma', 'nas-backup', 'home-ha'];
  if (rows >= 3) return all.sublist(0, math.min(rows, all.length));
  return all.sublist(3 - rows, 3);
}

/// The Critical topics preview.
class TopicsPreview extends StatelessWidget {
  const TopicsPreview({required this.size, super.key});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final layout = topicsPreviewLayoutFor(size);

    return LimitsPreviewTile(
      size: size,
      color: colors.surface,
      child: LimitsPreviewClock<TopicsPreviewFrame>(
        frameAt: topicsPreviewFrameAt,
        builder: (context, frame) => layout.isSwitchAlone
            ? Center(
                child: _Switch(
                  layout: layout,
                  knob: frame.knob,
                  track: frame.track,
                  frame: frame,
                ),
              )
            : _TopicList(layout: layout, frame: frame),
      ),
    );
  }
}

class _TopicList extends StatelessWidget {
  const _TopicList({required this.layout, required this.frame});

  final TopicsPreviewLayout layout;
  final TopicsPreviewFrame frame;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final names = topicsPreviewNames(layout.rows);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: layout.padding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, name) in names.indexed)
            Container(
              height: layout.rowHeight,
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: colors.hairline)),
              ),
              child: _TopicRow(
                layout: layout,
                name: name,
                // The names stand in for bars of different lengths.
                barLength: const [0.55, 0.9, 0.7, 0.6][i % 4],
                frame: i == layout.tappedRow ? frame : null,
                value: i < layout.tappedRow
                    ? 1
                    : i == layout.tappedRow
                    ? frame.knob
                    : frame.follower,
                track: i < layout.tappedRow
                    ? 1
                    : i == layout.tappedRow
                    ? frame.track
                    : frame.follower.clamp(0.0, 1.0),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.layout,
    required this.name,
    required this.barLength,
    required this.frame,
    required this.value,
    required this.track,
  });

  final TopicsPreviewLayout layout;
  final String name;
  final double barLength;

  /// The loop, on the row whose switch is tapped. Null on the others.
  final TopicsPreviewFrame? frame;
  final double value;
  final double track;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tapped = frame;
    final face = tapped == null
        ? FaceState.calm
        : tapped.isRefused
        ? FaceState.worried
        : tapped.isOn
        ? FaceState.happy
        : FaceState.calm;

    return Row(
      children: [
        FaceWidget(state: face, size: layout.faceSize),
        SizedBox(width: layout.gap),
        Expanded(
          child: layout.showsNames
              ? Text(
                  name,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: AppTypography.monoBold(
                    colors.ink,
                    fontSize: layout.nameSize,
                  ).copyWith(height: 1.2),
                )
              : FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: barLength,
                  child: Container(
                    height: layout.rowHeight * 0.16,
                    decoration: BoxDecoration(
                      color: colors.canvasGhostStrong,
                      borderRadius: Radii.fullAll,
                    ),
                  ),
                ),
        ),
        SizedBox(width: layout.gap),
        _Switch(layout: layout, knob: value, track: track, frame: tapped),
      ],
    );
  }
}

/// The app's switch, drawn at any size, with the tap mark and the shake of
/// the one that is tapped.
class _Switch extends StatelessWidget {
  const _Switch({
    required this.layout,
    required this.knob,
    required this.track,
    required this.frame,
  });

  final TopicsPreviewLayout layout;
  final double knob;
  final double track;
  final TopicsPreviewFrame? frame;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tapped = frame;

    return Transform.translate(
      // Sideways only. The switch never turns.
      offset: Offset((tapped?.shake ?? 0) * layout.switchWidth * 0.1, 0),
      child: CustomPaint(
        size: Size(layout.switchWidth, layout.switchHeight),
        painter: _SwitchPainter(
          knob: knob,
          trackColor: Color.lerp(colors.switchOff, colors.highlight, track)!,
          knobColor: Color.lerp(
            colors.switchThumbOff,
            colors.onHighlight,
            track,
          )!,
          shadowColor: colors.inkFixed,
          tapColor: colors.ink,
          tapOpacity: tapped?.tapOpacity ?? 0,
          tapScale: tapped?.tapScale ?? 1,
        ),
      ),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  const _SwitchPainter({
    required this.knob,
    required this.trackColor,
    required this.knobColor,
    required this.shadowColor,
    required this.tapColor,
    required this.tapOpacity,
    required this.tapScale,
  });

  final double knob;
  final Color trackColor;
  final Color knobColor;
  final Color shadowColor;
  final Color tapColor;
  final double tapOpacity;
  final double tapScale;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final inset = h * 3 / 28;
    final radius = h / 2 - inset;
    final travel = size.width - h;
    final center = Offset(h / 2 + travel * knob, h / 2);

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(h / 2)),
        Paint()..color = trackColor,
      )
      ..drawCircle(
        center.translate(0, h * 0.04),
        radius,
        Paint()
          ..color = shadowColor.withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.06),
      )
      ..drawCircle(center, radius, Paint()..color = knobColor);

    if (tapOpacity <= 0) return;
    // The tap lands where the knob waits, on the off side.
    final at = Offset(h / 2, h / 2);
    canvas
      ..drawCircle(
        at,
        h * 0.6 * tapScale,
        Paint()..color = tapColor.withValues(alpha: 0.14 * tapOpacity),
      )
      ..drawCircle(
        at,
        h * 0.6 * tapScale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.08
          ..color = tapColor.withValues(alpha: 0.6 * tapOpacity),
      );
  }

  @override
  bool shouldRepaint(_SwitchPainter old) =>
      old.knob != knob ||
      old.trackColor != trackColor ||
      old.knobColor != knobColor ||
      old.tapColor != tapColor ||
      old.tapOpacity != tapOpacity ||
      old.tapScale != tapScale;
}
