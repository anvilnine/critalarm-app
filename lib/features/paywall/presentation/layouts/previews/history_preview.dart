import 'dart:math' as math;

import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/history_own.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/limits_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_glyph_tile.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_size_class.dart';
import 'package:flutter/material.dart';

// History: a list of alarms by age scrolls down to the line where the free
// window ends and stops there. Then the line opens, the older rows can be
// read, and the list moves on. It rests with rows on both sides of the line.

/// Where the list is in its loop, in the order it happens.
enum HistoryPreviewPhase {
  /// Past the line, rows readable on both sides. The resting picture.
  rest,

  /// Scrolling back to the newest alarm, to play again.
  rewinding,

  /// At the newest alarm.
  top,

  /// Scrolling down to the line.
  scrolling,

  /// Stopped at the line: the free window ends here.
  stopped,

  /// The line opens, the older rows fill in, and the list scrolls on.
  lifting,
}

/// The seconds of the loop at which each phase starts.
abstract final class HistoryPreviewTimes {
  static const double rewind = 6.2;
  static const double top = 6.55;
  static const double scroll = 6.7;
  static const double stop = 7.35;
  static const double lift = 7.85;
  static const double rest = 8.75;
}

/// Everything the list picture needs at one moment.
@immutable
class HistoryPreviewFrame {
  const HistoryPreviewFrame({
    required this.phase,
    required this.toLine,
    required this.pastLine,
    required this.tug,
    required this.lift,
    required this.window,
  });

  final HistoryPreviewPhase phase;

  /// How far the list has scrolled from its top to the line, 0 to 1.
  final double toLine;

  /// How far it has scrolled on from there to where it rests, 0 to 1.
  final double pastLine;

  /// The small pull against the line while stopped, 0 to 1 and back.
  final double tug;

  /// How open the line is: 0 a wall with nothing readable under it, 1 a
  /// thin mark with every row under it readable.
  final double lift;

  /// Days of history in reach.
  final int window;

  @override
  bool operator ==(Object other) =>
      other is HistoryPreviewFrame &&
      other.phase == phase &&
      other.toLine == toLine &&
      other.pastLine == pastLine &&
      other.tug == tug &&
      other.lift == lift &&
      other.window == window;

  @override
  int get hashCode => Object.hash(phase, toLine, pastLine, tug, lift, window);
}

/// The phase at clock second [t].
HistoryPreviewPhase historyPreviewPhaseAt(double t) {
  final u = loopT(t, limitsPreviewPeriod);
  if (u < HistoryPreviewTimes.rewind) return HistoryPreviewPhase.rest;
  if (u < HistoryPreviewTimes.top) return HistoryPreviewPhase.rewinding;
  if (u < HistoryPreviewTimes.scroll) return HistoryPreviewPhase.top;
  if (u < HistoryPreviewTimes.stop) return HistoryPreviewPhase.scrolling;
  if (u < HistoryPreviewTimes.lift) return HistoryPreviewPhase.stopped;
  if (u < HistoryPreviewTimes.rest) return HistoryPreviewPhase.lifting;
  return HistoryPreviewPhase.rest;
}

/// The list at clock second [t], for a free window of [free] days and a
/// Hosted one of [hosted]. The loop starts and ends at rest.
HistoryPreviewFrame historyPreviewFrameAt(
  double t, {
  required int free,
  required int hosted,
}) {
  final u = loopT(t, limitsPreviewPeriod);
  final at = historyPreviewPhaseAt(t);

  double toLine = 1;
  double pastLine = 1;
  double tug = 0;
  double lift = 1;
  double reach = 1;

  switch (at) {
    case HistoryPreviewPhase.rest:
      break;
    case HistoryPreviewPhase.rewinding:
      final back = AppCurves.easeOut.transform(
        phase(u, HistoryPreviewTimes.rewind, HistoryPreviewTimes.top),
      );
      toLine = 1 - back;
      pastLine = 1 - back;
      lift = 1 - phase(u, HistoryPreviewTimes.rewind, HistoryPreviewTimes.top);
      reach = lift;
    case HistoryPreviewPhase.top:
      toLine = pastLine = lift = reach = 0;
    case HistoryPreviewPhase.scrolling:
      toLine = Curves.easeInOutCubic.transform(
        phase(u, HistoryPreviewTimes.scroll, HistoryPreviewTimes.stop),
      );
      pastLine = lift = reach = 0;
    case HistoryPreviewPhase.stopped:
      pastLine = lift = reach = 0;
      tug = limitsKeyframes(u, const [
        (HistoryPreviewTimes.stop, 0.0),
        (HistoryPreviewTimes.stop + 0.14, 1.0),
        (HistoryPreviewTimes.stop + 0.4, 0.0),
      ]);
    case HistoryPreviewPhase.lifting:
      lift = phase(
        u,
        HistoryPreviewTimes.lift,
        HistoryPreviewTimes.lift + 0.45,
      );
      pastLine = Curves.easeInOutCubic.transform(
        phase(u, HistoryPreviewTimes.lift + 0.1, HistoryPreviewTimes.rest),
      );
      reach = Curves.easeInOutCubic.transform(
        phase(u, HistoryPreviewTimes.lift, HistoryPreviewTimes.rest),
      );
  }

  return HistoryPreviewFrame(
    phase: at,
    toLine: toLine,
    pastLine: pastLine,
    tug: tug,
    lift: lift,
    window: (free + (hosted - free) * reach).round(),
  );
}

/// How open the row [index] places under the line is, 0 to 1, when the line
/// is [lift] open. The rows fill in one after another, nearest first.
double historyPreviewReveal(int index, double lift) {
  final start = math.min(index, 3) * 0.18;
  return phase(lift, start, start + 0.46);
}

/// Ages in days of the alarms listed inside a free window of [free] days,
/// newest first. Seven at most.
List<int> historyPreviewAgesInside(int free) {
  if (free <= 0) return const [];
  if (free <= 7) return [for (var day = 0; day < free; day++) day];
  return [for (var i = 0; i < 7; i++) ((free - 1) * i / 6).round()];
}

/// Ages in days of the alarms older than [free] days that a window of
/// [hosted] days keeps, newest first. The last one is [hosted] days old.
List<int> historyPreviewAgesBeyond(int free, int hosted) {
  if (hosted <= free) return const [];
  const parts = [0.03, 0.09, 0.2, 0.38, 0.55, 0.77, 1.0];
  final ages = <int>[];
  for (final part in parts) {
    final age = math.max(free + 1, (free + (hosted - free) * part).round());
    if (ages.isEmpty || age > ages.last) ages.add(age);
  }
  return ages;
}

/// How the scene is laid out in a box: rows of a face, a topic name and an
/// age, with bars for the words where they would be too small to read.
@immutable
class HistoryPreviewLayout {
  const HistoryPreviewLayout({
    required this.size,
    required this.rowHeight,
    required this.padding,
    required this.textSize,
    required this.tagSize,
  });

  /// Where the line sits in the box, top to bottom, when the list stops at
  /// it.
  static const double stopAt = 0.72;

  /// Where the line sits when the list rests: a little above the middle,
  /// and in the middle of a box too short for more than a row each side.
  double get restAt => size.height / rowHeight < 3.4 ? 0.5 : 0.42;

  final Size size;
  final double rowHeight;
  final double padding;

  /// Type size of a row. Zero draws bars.
  final double textSize;

  /// Type size of the day counts on the line and in the corner. Zero
  /// leaves them out.
  final double tagSize;

  bool get showsText => textSize > 0;
  bool get showsTags => tagSize > 0;
  double get faceSize => rowHeight * 0.6;
  double get gap => rowHeight * 0.2;

  /// Height of the place the line takes in the list.
  double get lineSlot => rowHeight * 0.62;

  /// Top of the line's place, in the list, under [inside] rows. With none,
  /// the line is the first thing in the list and would sit at the top edge
  /// of the card, where a layout may lay a tag across it. It stands
  /// [historyPreviewTagRoom] below the edge, and a little more for the
  /// tug, which moves the list up.
  double lineTop(int inside) => inside == 0
      ? historyPreviewTagRoom + rowHeight * 0.16
      : inside * rowHeight;

  /// How far below the card's top edge the list starts when [inside] rows
  /// are above the line. The tag a layout lays across the card's top edge
  /// reaches [historyPreviewTagRoom] into it, so the first row starts below
  /// that. With no rows above, the line's own offset already keeps clear.
  double listOffset(int inside) => inside == 0 ? 0 : historyPreviewTagRoom;

  /// Where row [i] inside the window starts in the card, not scrolled.
  double rowTop(int i) => historyPreviewTagRoom + i * rowHeight;

  /// Where row [j] past the line starts in the card, not scrolled, under
  /// [inside] rows.
  double beyondRowTop(int j, int inside) =>
      listOffset(inside) + lineTop(inside) + lineSlot + j * rowHeight;

  /// The scrolls at which a row of the window starts exactly at the tag
  /// room: the first row, and each other one while the line is still below
  /// the tag. A list that rests on one of them is cut by nothing but the
  /// card's bottom edge.
  List<double> wholeRowScrolls(int inside) => [
    for (var i = 0; i <= inside; i++) i * rowHeight,
  ];

  /// How far the list is scrolled when it rests, under [inside] rows: the
  /// whole row scroll that puts the line nearest to where it rests
  /// ([restAt] of the way down).
  double restScrollFor(int inside) {
    final center = listOffset(inside) + lineTop(inside) + lineSlot / 2;
    final wanted = math.max(0, center - restAt * size.height).toDouble();
    var best = 0.0;
    var away = double.infinity;
    for (final candidate in wholeRowScrolls(inside)) {
      final gap = (candidate - wanted).abs();
      if (gap < away) {
        away = gap;
        best = candidate;
      }
    }
    return best;
  }

  /// The scroll a card draws for [frame]: [scrollFor], except that where it
  /// rests it rests on a whole row (see [restScrollFor]). The list is
  /// clipped under the tag room, so a row on its way past is cut there,
  /// and none is left cut when the list stops.
  double shownScrollFor(HistoryPreviewFrame frame, int inside) {
    final center = listOffset(inside) + lineTop(inside) + lineSlot / 2;
    final stop = math.max(0, center - stopAt * size.height).toDouble();
    final rest = restScrollFor(inside);
    return stop * frame.toLine +
        (rest - stop) * frame.pastLine +
        rowHeight * 0.16 * frame.tug;
  }

  /// How far the list is scrolled for [frame], under [inside] rows.
  double scrollFor(HistoryPreviewFrame frame, int inside) {
    final center = lineTop(inside) + lineSlot / 2;
    final stop = math.max(0, center - stopAt * size.height).toDouble();
    final rest = math.max(0, center - restAt * size.height).toDouble();
    return stop * frame.toLine +
        (rest - stop) * frame.pastLine +
        rowHeight * 0.16 * frame.tug;
  }
}

HistoryPreviewLayout historyPreviewLayoutFor(Size size) {
  final w = size.width;
  final h = size.height;

  final ideal = (w * 0.24).clamp(22.0, 48.0);
  final rowHeight = h / (h / ideal).clamp(2.6, 6.5);
  final padding = size.shortestSide * 0.08;
  // A name and an age, in characters, beside the face.
  final textRoom = w - 2 * padding - rowHeight * 0.6 - 2 * rowHeight * 0.2;
  final textSize = math.min(rowHeight * 0.3, textRoom / 8.6);
  final tagSize = math.min<double>(rowHeight * 0.36, 15);

  return HistoryPreviewLayout(
    size: size,
    rowHeight: rowHeight,
    padding: padding,
    textSize: textSize >= limitsPreviewMinType ? textSize : 0,
    tagSize: tagSize >= limitsPreviewMinType ? tagSize : 0,
  );
}

/// How far below the card's top edge a tag laid across that edge reaches, in
/// points, at the largest text size a tag grows to. With no rows above it,
/// the line starts below this.
const double historyPreviewTagRoom = 20;

/// An age as the list writes it.
String historyPreviewAge(int days) => '${days}d'; // l10n-ok: unit letter

const _topics = ['prod-db', 'uptime-kuma', 'nas-backup', 'home-ha'];
const _barLengths = [0.62, 0.9, 0.74, 0.54, 0.82];

/// One row of the list: a topic name and an age in days.
typedef _Entry = ({String name, int age});

/// The history preview.
///
/// With [own] it draws the person's real alarms: the few inside the Free
/// window, and the ones past it as hidden rows, each struck through while
/// the line is closed. The phone holds those rows and only hides them, so
/// none is ever left out of the list. Without [own] it draws made-up rows.
class HistoryPreview extends StatelessWidget {
  const HistoryPreview({required this.size, this.own, super.key});

  final Size size;

  /// The person's own alarms, or null for the made-up ones. Their topic
  /// names are drawn here and go nowhere else.
  final HistoryOwn? own;

  @override
  Widget build(BuildContext context) {
    if (size.shortestSide < paywallPreviewSceneMinEdge) {
      return PreviewGlyphTile.glyph(GlyphType.clock, size: size);
    }

    final colors = context.appColors;
    final free = AccountCaps.free.historyDays ?? 0;
    const hosted = hostedHistoryDays;
    final layout = historyPreviewLayoutFor(size);
    final person = own;
    final isOwn = person != null;
    final inside = <_Entry>[
      if (person != null)
        for (final row in person.inside) (name: row.topic, age: row.ageDays)
      else
        for (final (i, age) in historyPreviewAgesInside(free).indexed)
          (name: _topics[i % _topics.length], age: age),
    ];
    final beyond = <_Entry>[
      if (person != null)
        for (final row in person.beyond) (name: row.topic, age: row.ageDays)
      else
        for (final (j, age) in historyPreviewAgesBeyond(free, hosted).indexed)
          (name: _topics[(j + 3) % _topics.length], age: age),
    ];

    return LimitsPreviewTile(
      size: size,
      color: colors.surface,
      child: PaywallPreviewClock<HistoryPreviewFrame>(
        restAt: limitsPreviewRestAt,
        // Told when to play, it starts on its own turn of the shared loop.
        turnStart: HistoryPreviewTimes.rewind,
        frameAt: (t) => historyPreviewFrameAt(t, free: free, hosted: hosted),
        builder: (context, frame) {
          final scroll = layout.shownScrollFor(frame, inside.length);
          final offset = layout.listOffset(inside.length);
          final lineTop = offset + layout.lineTop(inside.length) - scroll;
          final beyondTop = lineTop + layout.lineSlot;

          bool inView(double top) =>
              top < size.height && top + layout.rowHeight > 0;

          return ClipRect(
            clipper: const _BelowTagRoom(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (i, entry) in inside.indexed)
                  if (inView(layout.rowTop(i) - scroll))
                    Positioned(
                      top: layout.rowTop(i) - scroll,
                      left: 0,
                      right: 0,
                      height: layout.rowHeight,
                      child: _HistoryRow(
                        layout: layout,
                        name: entry.name,
                        nameLength: _barLengths[i % _barLengths.length],
                        age: entry.age,
                        isBeyond: false,
                        isOwn: isOwn,
                        reveal: 1,
                        hasRule: i > 0,
                      ),
                    ),
                for (final (j, entry) in beyond.indexed)
                  if (inView(beyondTop + j * layout.rowHeight))
                    Positioned(
                      top: beyondTop + j * layout.rowHeight,
                      left: 0,
                      right: 0,
                      height: layout.rowHeight,
                      child: _HistoryRow(
                        layout: layout,
                        name: entry.name,
                        nameLength: _barLengths[(j + 3) % _barLengths.length],
                        age: entry.age,
                        isBeyond: true,
                        isOwn: isOwn,
                        reveal: historyPreviewReveal(j, frame.lift),
                        hasRule: j > 0,
                      ),
                    ),
                Positioned(
                  top: lineTop,
                  left: 0,
                  right: 0,
                  height: layout.lineSlot,
                  child: _FreeLine(
                    layout: layout,
                    lift: frame.lift,
                    days: free,
                    window: frame.window,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Keeps what is under the room the tag takes at the card's top edge, and
/// everything to the sides.
class _BelowTagRoom extends CustomClipper<Rect> {
  const _BelowTagRoom();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    -size.width,
    historyPreviewTagRoom,
    size.width * 2,
    size.height,
  );

  @override
  bool shouldReclip(_BelowTagRoom oldClipper) => false;
}

/// One alarm in the list. Under the line it is a faint outline until the
/// line opens.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.layout,
    required this.name,
    required this.nameLength,
    required this.age,
    required this.isBeyond,
    required this.isOwn,
    required this.reveal,
    required this.hasRule,
  });

  final HistoryPreviewLayout layout;
  final String name;

  /// How long the bar that stands in for the name is, 0 to 1.
  final double nameLength;
  final int age;
  final bool isBeyond;

  /// The row is one of the person's own. Hidden, it is struck through, so
  /// the picture reads as hidden and never as missing.
  final bool isOwn;
  final double reveal;
  final bool hasRule;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // Ink on both sides of the line. What the line opens up is told apart
    // by weight: the ages past it are full ink, the ones inside are muted.
    final mark = colors.ink;

    Widget bar(double width, Color color) => Container(
      width: width,
      height: layout.rowHeight * 0.16,
      decoration: BoxDecoration(color: color, borderRadius: Radii.fullAll),
    );

    final room =
        layout.size.width -
        2 * layout.padding -
        layout.faceSize -
        2 * layout.gap;

    Widget row({required bool isGhost}) {
      final faint = colors.ink.withValues(alpha: 0.16);
      final cells = Row(
        children: [
          if (isGhost)
            Container(
              width: layout.faceSize,
              height: layout.faceSize,
              decoration: BoxDecoration(
                color: faint,
                borderRadius: BorderRadius.circular(layout.faceSize * 0.3),
              ),
            )
          else
            FaceWidget(
              state: FaceState.calm,
              size: layout.faceSize,
            ),
          SizedBox(width: layout.gap),
          if (isGhost || !layout.showsText) ...[
            bar(
              room * 0.7 * nameLength,
              isGhost ? faint : colors.canvasGhostStrong,
            ),
            const Spacer(),
            bar(
              room * 0.16,
              isGhost
                  ? faint
                  : isBeyond
                  ? mark
                  : colors.ink3,
            ),
          ] else ...[
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                softWrap: false,
                overflow: isOwn ? TextOverflow.ellipsis : TextOverflow.clip,
                style: AppTypography.monoBold(
                  colors.ink,
                  fontSize: layout.textSize,
                ).copyWith(height: 1.2),
              ),
            ),
            SizedBox(width: layout.gap),
            Text(
              historyPreviewAge(age),
              style: AppTypography.monoBold(
                isBeyond ? mark : colors.ink3,
                fontSize: layout.textSize,
              ).copyWith(height: 1.2),
            ),
          ],
        ],
      );
      if (!isGhost || !isOwn) return cells;
      // A hidden row of the person's own, struck through its name. It goes
      // as the row fills in, with the rest of the outline.
      final nameWidth = room * 0.7 * nameLength;
      return Stack(
        alignment: Alignment.centerLeft,
        children: [
          cells,
          Padding(
            padding: EdgeInsets.only(left: layout.faceSize + layout.gap * 0.5),
            child: Container(
              width: nameWidth + layout.gap,
              height: math.max(1.5, layout.rowHeight * 0.05),
              color: colors.ink.withValues(alpha: 0.55),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: layout.padding),
      decoration: BoxDecoration(
        border: hasRule
            ? Border(top: BorderSide(color: colors.hairline))
            : null,
      ),
      child: reveal >= 1
          ? row(isGhost: false)
          : reveal <= 0
          ? row(isGhost: true)
          : Stack(
              fit: StackFit.expand,
              children: [
                Opacity(opacity: 1 - reveal, child: row(isGhost: true)),
                Opacity(opacity: reveal, child: row(isGhost: false)),
              ],
            ),
    );
  }
}

/// The line where the free window ends. Closed it is a band across the
/// list with the free day count on it. Open it is a thin mark, and the days
/// now in reach are written at its other end.
class _FreeLine extends StatelessWidget {
  const _FreeLine({
    required this.layout,
    required this.lift,
    required this.days,
    required this.window,
  });

  final HistoryPreviewLayout layout;
  final double lift;
  final int days;
  final int window;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final thin = math.max(1.5, layout.rowHeight * 0.07);
    final thickness = layout.lineSlot + (thin - layout.lineSlot) * lift;

    Widget tag(int count, Color color, Color onColor) => Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.tagSize * 0.55,
        vertical: layout.tagSize * 0.12,
      ),
      decoration: BoxDecoration(color: color, borderRadius: Radii.fullAll),
      child: Text(
        historyPreviewAge(count),
        style: AppTypography.monoBold(onColor, fontSize: layout.tagSize)
            .copyWith(
              height: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(height: thickness, color: colors.ink),
        if (layout.showsTags)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: layout.padding),
            child: Row(
              children: [
                tag(days, colors.ink, colors.surface),
                const Spacer(),
                // Comes in as the line opens, counting up.
                if (lift > 0)
                  Transform.scale(
                    scale: AppCurves.easeSpring.transform(lift),
                    child: tag(window, colors.ink, colors.surface),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
