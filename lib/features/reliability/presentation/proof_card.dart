import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_weeks.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// The dark card under the list on "Will it wake me?": how many of the last
// eight weeks a test or a weekly check got through, as eight dots, with the
// weekly delivery check inside it. The phone's own log
// (`domain/proof/proof_log.dart`) is the only source. Which dot shows what
// comes from `proofCardViewFor`, so it is unit tested and the widget only
// draws it.

/// What one dot shows.
@immutable
final class ProofDotView {
  const ProofDotView({
    required this.monday,
    required this.mark,
    required this.isThisWeek,
    required this.label,
  });

  final DateTime monday;
  final ProofMark mark;

  /// The newest dot, the week of now. It wears a double ring.
  final bool isThisWeek;

  /// What a screen reader says for the dot.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is ProofDotView &&
      other.monday == monday &&
      other.mark == mark &&
      other.isThisWeek == isThisWeek &&
      other.label == label;

  @override
  int get hashCode => Object.hash(monday, mark, isThisWeek, label);
}

/// What the card shows: the count and the dots.
@immutable
final class ProofCardView {
  const ProofCardView({required this.count, required this.dots});

  /// How many weeks rang. A failed week is not counted.
  final int count;
  final List<ProofDotView> dots;

  /// Nothing rang, so the value is drawn muted.
  bool get isEmpty => count == 0;
}

/// The words for a dot of [mark] in the week of [monday].
String proofDotLabel(DateTime monday, ProofMark mark) {
  final date = DateFormat('d MMM').format(monday);
  return switch (mark) {
    ProofMark.rang => LocaleKeys.proof_card_dot_rang,
    ProofMark.failed => LocaleKeys.proof_card_dot_failed,
    ProofMark.none => LocaleKeys.proof_card_dot_none,
  }.tr(namedArgs: {'date': date});
}

/// The card for [weeks], oldest first and ending with the week of [now].
/// Fewer weeks than eight are drawn as they come.
ProofCardView proofCardViewFor(List<ProofWeek> weeks, DateTime now) {
  final current = proofWeekStart(now);
  return ProofCardView(
    count: proofRangCount(weeks),
    dots: [
      for (final week in weeks)
        () {
          final isThisWeek = week.monday == current;
          final label = proofDotLabel(week.monday, week.mark);
          return ProofDotView(
            monday: week.monday,
            mark: week.mark,
            isThisWeek: isThisWeek,
            label: isThisWeek
                ? LocaleKeys.proof_card_dot_this_week.tr(
                    namedArgs: {'label': label},
                  )
                : label,
          );
        }(),
    ],
  );
}

/// How far dot [index] has filled, 0 to 1, [elapsed] after the card showed.
///
/// The dots start [stagger] apart, left to right, and the last one ends at
/// [total]. Linear: the curve is the painter's.
double proofDotFillAt(
  int index,
  Duration elapsed, {
  int count = proofShownWeeks,
  Duration stagger = const Duration(milliseconds: 30),
  Duration total = AppDurations.slow,
}) {
  final span = total - stagger * (count - 1);
  if (span <= Duration.zero) return elapsed >= total ? 1 : 0;
  final into = elapsed - stagger * index;
  return (into.inMicroseconds / span.inMicroseconds).clamp(0.0, 1.0);
}

/// The dark proof card: the label, the count, the eight dots, a hairline and
/// [weeklyCheck] below it.
///
/// It redraws when [log] changes. The first time it is built the dots that
/// rang or failed fill from left to right. Under reduced motion they are
/// filled at once and no ticker runs.
class ProofCard extends StatefulWidget {
  const ProofCard({
    required this.log,
    required this.weeklyCheck,
    this.now = DateTime.now,
    super.key,
  });

  final ProofLog log;

  /// The weekly delivery check row, drawn inside the card.
  final Widget weeklyCheck;

  /// The clock, so the week of now can be set.
  final DateTime Function() now;

  @override
  State<ProofCard> createState() => _ProofCardState();
}

class _ProofCardState extends State<ProofCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: AppDurations.slow,
  );
  StreamSubscription<void>? _changes;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _changes = widget.log.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) {
      _fill.value = 1;
    } else {
      unawaited(_fill.forward());
    }
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = widget.now();
    final view = proofCardViewFor(widget.log.weeks(now), now);
    final value = LocaleKeys.proof_card_value.tr(
      namedArgs: {'n': '${view.count}'},
    );
    final range = LocaleKeys.proof_card_range.tr();

    final header = Semantics(
      container: true,
      header: true,
      label: LocaleKeys.proof_card_card_aria_label.tr(
        namedArgs: {'value': value, 'range': range},
      ),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                LocaleKeys.proof_card_label.tr().toUpperCase(),
                style: AppTypography.monoBold(
                  colors.onPanel,
                  fontSize: 10.5,
                ).copyWith(letterSpacing: 10.5 * 0.1, height: 1.2),
              ),
              const Spacer(),
              Text(
                range,
                style: AppTypography.mono(
                  colors.onPanelMuted,
                  fontSize: 11,
                ).copyWith(letterSpacing: 0),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.headline(
              view.isEmpty ? colors.onPanelMuted : colors.yellow,
              fontSize: 30,
            ).copyWith(height: 1.05),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: Radii.xlAll,
          // The dark panel is nearly the dark canvas, so on the dark theme a
          // hairline sets it apart, as on the other dark panels.
          border: isDark ? Border.all(color: colors.panelLine) : null,
          boxShadow: [
            BoxShadow(
              color: colors.panel.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: _fill,
                builder: (context, _) => _ProofDots(
                  dots: view.dots,
                  elapsed: AppDurations.slow * _fill.value,
                ),
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.panelLine)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: widget.weeklyCheck,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The row of dots. Each is its own spoken piece with no tap and no role.
class _ProofDots extends StatelessWidget {
  const _ProofDots({required this.dots, required this.elapsed});

  final List<ProofDotView> dots;
  final Duration elapsed;

  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        for (var i = 0; i < dots.length; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Semantics(
                container: true,
                label: dots[i].label,
                excludeSemantics: true,
                child: CustomPaint(
                  painter: _DotPainter(
                    mark: dots[i].mark,
                    isThisWeek: dots[i].isThisWeek,
                    fill: AppCurves.easeOut.transform(
                      proofDotFillAt(i, elapsed, count: dots.length),
                    ),
                    outline: colors.onPanelMuted.withValues(alpha: 0.5),
                    rang: colors.yellow,
                    failed: colors.crit,
                    ring: colors.yellow,
                  ),
                  child: dots[i].mark == ProofMark.failed
                      ? Center(
                          child: Opacity(
                            opacity: AppCurves.easeOut.transform(
                              proofDotFillAt(i, elapsed, count: dots.length),
                            ),
                            child: Text(
                              '!', // l10n-ok: a mark, not a word
                              textScaler: TextScaler.noScaling,
                              style: AppTypography.headline(
                                colors.inkFixed,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter({
    required this.mark,
    required this.isThisWeek,
    required this.fill,
    required this.outline,
    required this.rang,
    required this.failed,
    required this.ring,
  });

  final ProofMark mark;
  final bool isThisWeek;

  /// 0 to 1, how much of a filled dot is drawn. A dot with no mark ignores it.
  final double fill;
  final Color outline;
  final Color rang;
  final Color failed;
  final Color ring;

  static const double _dash = 4;
  static const double _dashGap = 3.5;
  static const double _stroke = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    if (mark == ProofMark.none) {
      _dashed(canvas, center, radius - _stroke / 2);
    } else {
      // The empty dot is under the one that fills, so the circle does not
      // jump when it starts.
      _dashed(canvas, center, radius - _stroke / 2);
      canvas.drawCircle(
        center,
        radius * fill,
        Paint()..color = mark == ProofMark.failed ? failed : rang,
      );
    }

    if (isThisWeek) {
      // Three points of the card, then two points of yellow.
      canvas.drawCircle(
        center,
        radius + 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ring,
      );
    }
  }

  void _dashed(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = outline;
    final circumference = 2 * math.pi * radius;
    const unit = _dash + _dashGap;
    final count = (circumference / unit).round().clamp(6, 64);
    final sweep = 2 * math.pi / count;
    final dashSweep = sweep * (_dash / unit);
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, i * sweep, dashSweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.mark != mark ||
      old.isThisWeek != isThisWeek ||
      old.fill != fill ||
      old.outline != outline ||
      old.rang != rang ||
      old.failed != failed ||
      old.ring != ring;
}
