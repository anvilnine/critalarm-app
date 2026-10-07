import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The mascot on a stage, reacting to one benefit playing large beside it,
/// over a headline and the benefits as plain lines.
///
/// The stage is the one thing that moves. It takes every point of height
/// the words under it do not need, so the screen is full on any phone. The
/// line of the benefit playing is the strong one in the list.
///
/// It answers the hand. A swipe across the stage goes to the next benefit
/// or the previous one, a tap on a line puts that benefit on the stage,
/// and a tap on the stage plays the current one again. The chosen benefit
/// plays its turn, holds for a moment, and the loop goes on from there.
///
/// An id with no layout of its own draws this one.
class HeroPaywallLayout extends StatelessWidget {
  const HeroPaywallLayout({super.key});

  /// The side inset of the buy block.
  static const double _side = 20;

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      // The mascot stands in the top left, so the cross takes the right.
      closeOnLeft: false,
      restAt: heroEntranceSeconds,
      builder: (context, scope) => _Hero(scope: scope),
    );
  }
}

/// The line the list shows for [benefit]: a short sentence of its own
/// where the layout has one, the benefit's title where it has none.
String heroLineFor(PaywallBenefit benefit) {
  final key = switch (benefit.id) {
    PaywallBenefitId.topics => LocaleKeys.paywall_hero_lines_topics,
    PaywallBenefitId.pushes => LocaleKeys.paywall_hero_lines_pushes,
    PaywallBenefitId.history => LocaleKeys.paywall_hero_lines_history,
    PaywallBenefitId.widgets => LocaleKeys.paywall_hero_lines_widgets,
    PaywallBenefitId.appIcons => LocaleKeys.paywall_hero_lines_app_icons,
    PaywallBenefitId.wakeUpChallenges =>
      LocaleKeys.paywall_hero_lines_wake_up_challenges,
    PaywallBenefitId.reliabilityChecks =>
      LocaleKeys.paywall_hero_lines_reliability_checks,
    PaywallBenefitId.customSounds =>
      LocaleKeys.paywall_hero_lines_custom_sounds,
    PaywallBenefitId.customAlarmScreens =>
      LocaleKeys.paywall_hero_lines_custom_alarm_screens,
  };
  return key.tr(namedArgs: HostedBenefit.args);
}

/// What the composition measures on one phone.
class _Sizes {
  const _Sizes({
    required this.headline,
    required this.line,
    required this.check,
    required this.rowGap,
    required this.stageGap,
    required this.headlineGap,
    required this.bottomGap,
  });

  factory _Sizes.of({required bool isCompact}) => isCompact
      ? const _Sizes(
          headline: 26,
          line: 14.5,
          check: 18,
          rowGap: 5,
          stageGap: Spacing.s2,
          headlineGap: 10,
          bottomGap: Spacing.s3,
        )
      : const _Sizes(
          headline: 30,
          line: 16,
          check: 20,
          rowGap: 9,
          stageGap: Spacing.s3,
          headlineGap: 14,
          bottomGap: 20,
        );

  final double headline;
  final double line;
  final double check;
  final double rowGap;

  /// Between the stage and the headline.
  final double stageGap;

  /// Between the headline and the lines.
  final double headlineGap;

  /// Between the last line and the buy block.
  final double bottomGap;

  static const double checkGap = 10;
}

/// The line under a tap [y] points down a column of lines whose middles
/// are at [centres], or null when the tap is on none.
///
/// Every line answers a tap within [reach] of its middle, so each has a
/// tap area twice that tall however close the lines sit. Where two areas
/// overlap, the nearer line takes the tap.
int? heroLineAt(double y, List<double> centres, {double reach = 22}) {
  int? best;
  var nearest = double.infinity;
  for (final (i, centre) in centres.indexed) {
    final away = (y - centre).abs();
    if (away <= reach && away < nearest) {
      nearest = away;
      best = i;
    }
  }
  return best;
}

/// How far the card follows a finger that has moved [dragged] points
/// sideways: closely at first, then less and less, never past [limit].
double heroPullFor(double dragged, {double limit = 56}) =>
    limit * dragged / (limit * 1.6 + dragged.abs());

/// Whether a finger that moved [dragged] points and left at [velocity]
/// points a second has asked for another benefit, and which: 1 is the
/// next (a swipe to the left), -1 the previous, 0 neither.
int heroSwipeStep(double dragged, double velocity) {
  if (velocity.abs() >= 320) return velocity < 0 ? 1 : -1;
  if (dragged.abs() >= 44) return dragged < 0 ? 1 : -1;
  return 0;
}

class _Hero extends StatefulWidget {
  const _Hero({required this.scope});

  final PaywallLayoutScope scope;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  /// The stage stops growing here. Past it the mascot and the card are at
  /// their largest, and more height is only more air.
  static const double _stageMax = 380;

  /// How long the card takes to spring back when the finger lets go
  /// without asking for another benefit.
  static const double _settleSeconds = 0.36;

  /// The strip along the left edge where the route's own back swipe
  /// listens. A touch on the stage there is the stage's.
  static const double _backEdge = 24;

  /// What the hand last chose. Null while the loop runs untouched.
  HeroHand? _hand;

  /// How far the finger has moved sideways in the drag under way.
  double _dragged = 0;
  bool _isDragging = false;

  /// The pull the finger let go of, and the clock second it did.
  double _released = 0;
  double _releasedAt = 0;

  PaywallLayoutScope get scope => widget.scope;
  PaywallClock get _clock => scope.clock;

  late HeroLoop _loop;

  /// The card's offset under the finger at clock second [t].
  double _pullAt(double t) {
    if (_clock.isStill) return 0;
    if (_isDragging) return heroPullFor(_dragged);
    if (_released == 0) return 0;
    return _released *
        (1 -
            AppCurves.easeSpring.transform(
              phase(t, _releasedAt, _releasedAt + _settleSeconds),
            ));
  }

  HeroFrame _frameAt(double t) =>
      _loop.frameAt(t, isStill: _clock.isStill, hand: _hand);

  /// Takes a touch: a line by [index], a swipe by [step], or neither for a
  /// tap on the stage.
  void _touch({int? index, int step = 0, double pull = 0}) {
    final t = _clock.value;
    final before = _loop.chosenAt(t, hand: _hand);
    final hand = _loop.touch(
      t,
      hand: _hand,
      index: index,
      step: step,
      pull: pull,
      isStill: _clock.isStill,
    );
    if (hand == null) return;
    if (hand.index != before) {
      AppHaptics.selection();
      getIt<PaywallCues>().tick();
    }
    setState(() => _hand = hand);
  }

  void _onDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragged = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragged += details.primaryDelta ?? 0;
  }

  void _onDragEnd(DragEndDetails details) {
    final pull = _clock.isStill ? 0.0 : heroPullFor(_dragged);
    final step = heroSwipeStep(_dragged, details.primaryVelocity ?? 0);
    final wasTap = _dragged.abs() < kTouchSlop;
    _isDragging = false;
    _dragged = 0;
    if (step != 0) {
      // The old card leaves from where the finger let go of it.
      _released = 0;
      _touch(step: step, pull: pull);
    } else {
      _released = pull;
      _releasedAt = _clock.value;
      // A touch at the edge is taken as a drag before it has moved. One
      // that never did move was a tap.
      if (wasTap) _touch();
    }
  }

  void _onDragCancel() {
    _released = _clock.isStill ? 0 : heroPullFor(_dragged);
    _releasedAt = _clock.value;
    _isDragging = false;
    _dragged = 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sizes = _Sizes.of(isCompact: scope.isCompact);
    final width = scope.size.width - HeroPaywallLayout._side * 2;
    final textWidth = width - sizes.check - _Sizes.checkGap;
    final benefits = scope.benefits;
    final isOne = benefits.length == 1;

    final headline = scope.isHosted
        ? LocaleKeys.paywall_hero_headline_hosted.tr()
        : LocaleKeys.paywall_hero_headline_pro.tr();
    final headlineStyle = AppTypography.headline(
      colors.onCanvas,
      fontSize: sizes.headline,
    );
    final strongStyle = AppTypography.small(
      colors.onCanvas,
      fontSize: sizes.line,
    ).copyWith(fontWeight: FontWeight.w700, height: 1.3);
    final quietStyle = strongStyle.copyWith(
      color: colors.onCanvasMuted,
      fontWeight: FontWeight.w500,
    );
    final sentenceStyle = AppTypography.small(
      colors.onCanvasMuted,
      fontSize: sizes.line,
    ).copyWith(height: 1.35);

    final lines = [for (final b in benefits) heroLineFor(b)];
    // A line keeps its height whether it is the strong one or not, so the
    // list never moves as the stage plays.
    double rowHeight(String text) => math.max(
      sizes.check,
      paywallTextHeight(context, text, strongStyle, textWidth),
    );
    final rowHeights = [for (final line in lines) rowHeight(line)];
    final sentence = isOne ? benefits.single.line : null;
    final sentenceHeight = sentence == null
        ? 0.0
        : Spacing.s1 +
              paywallTextHeight(context, sentence, sentenceStyle, textWidth);
    final headlineHeight = paywallTextHeight(
      context,
      headline,
      headlineStyle,
      width,
    );
    final words =
        headlineHeight +
        sizes.headlineGap +
        rowHeights.fold(0, (sum, h) => sum + h) +
        sizes.rowGap * math.max(0, lines.length - 1) +
        sentenceHeight;

    // Where the middle of each line is, down the block of words. A tap is
    // matched to a line with these.
    final centres = <double>[];
    var y = headlineHeight + sizes.headlineGap;
    for (final (i, height) in rowHeights.indexed) {
      if (i > 0) y += sizes.rowGap;
      centres.add(y + height / 2);
      y += height;
    }

    // The stage takes what the words leave. Past its largest, the spare
    // height is shared out: most above and below the words, some to the
    // stage.
    final left = scope.size.height - words - sizes.stageGap - sizes.bottomGap;
    final spare = math.max(0, left - _stageMax);
    final stageHeight = math.max(0, math.min(left, _stageMax) + spare * 0.4);
    final stageGap = sizes.stageGap + spare * 0.3;
    // The room under the last line belongs to the lines, so the last one
    // has its full tap area. It ends where the buy block starts.
    final under = math.max(
      0,
      scope.size.height - stageHeight.floorToDouble() - stageGap - words,
    );

    _loop = HeroLoop([for (final b in benefits) b.previewId]);
    final bleedTop = MediaQuery.viewPaddingOf(context).top;

    // At the default text size this fits exactly. Where a large text size
    // leaves the stage no room, the words scroll in their own box and the
    // frame still does not.
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    TapGestureRecognizer.new,
                    (tap) => tap.onTap = _touch,
                  ),
              _StageDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<_StageDragRecognizer>(
                    () => _StageDragRecognizer(edge: _backEdge),
                    (drag) => drag
                      ..onStart = _onDragStart
                      ..onUpdate = _onDragUpdate
                      ..onEnd = _onDragEnd
                      ..onCancel = _onDragCancel,
                  ),
            },
            child: PaywallClockBuilder(
              clock: scope.clock,
              builder: (context, t, _) {
                final isStill = scope.clock.isStill;
                final frame = _frameAt(t);
                return Semantics(
                  container: true,
                  image: true,
                  label: lines.isEmpty
                      ? null
                      : LocaleKeys.paywall_hero_stage_label.tr(
                          namedArgs: {'benefit': lines[frame.activeIndex]},
                        ),
                  child: HeroStage(
                    size: Size(scope.size.width, stageHeight.floorToDouble()),
                    frame: frame,
                    seconds: isStill ? 0 : t,
                    bleedTop: bleedTop,
                    pull: _pullAt(t),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: stageGap,
            child: lines.length < 2
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HeroPaywallLayout._side,
                    ),
                    child: ExcludeSemantics(
                      child: PaywallClockBuilder(
                        clock: scope.clock,
                        builder: (context, t, _) => CustomPaint(
                          painter: _PipsPainter(
                            count: lines.length,
                            frame: _frameAt(t),
                            show: scope.clock.isStill
                                ? 1
                                : phase(t, 0.5, heroEntranceSeconds),
                            color: colors.onCanvas,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapUp: isOne
                ? null
                : (details) {
                    final line = heroLineAt(details.localPosition.dy, centres);
                    if (line != null) _touch(index: line);
                  },
            child: Padding(
              padding: EdgeInsets.only(
                left: HeroPaywallLayout._side,
                right: HeroPaywallLayout._side,
                bottom: under.toDouble(),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rise(
                    clock: scope.clock,
                    index: 0,
                    child: Semantics(
                      header: true,
                      child: Text(headline, style: headlineStyle),
                    ),
                  ),
                  SizedBox(height: sizes.headlineGap),
                  for (final (i, line) in lines.indexed) ...[
                    if (i > 0) SizedBox(height: sizes.rowGap),
                    _Rise(
                      clock: scope.clock,
                      index: i + 1,
                      child: SizedBox(
                        height: rowHeights[i],
                        child: _Line(
                          clock: scope.clock,
                          frameAt: _frameAt,
                          index: i,
                          text: line,
                          // What the short line leaves out is still said.
                          label: isOne ? null : benefits[i].line,
                          onTap: isOne ? null : () => _touch(index: i),
                          sizes: sizes,
                          strong: strongStyle,
                          quiet: quietStyle,
                        ),
                      ),
                    ),
                  ],
                  if (sentence != null)
                    _Rise(
                      clock: scope.clock,
                      index: 2,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: Spacing.s1,
                          left: sizes.check + _Sizes.checkGap,
                        ),
                        child: Text(sentence, style: sentenceStyle),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The stage's sideways drag. Along the left edge of the screen the route
/// listens for its own back swipe, and would take a drag that starts
/// there: so a touch in that strip is claimed at once, and a swipe that
/// starts on the stage never closes the screen.
class _StageDragRecognizer extends HorizontalDragGestureRecognizer {
  _StageDragRecognizer({required this.edge});

  final double edge;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (event.position.dx < edge) resolve(GestureDisposition.accepted);
  }
}

/// One small pip per benefit, under the stage. The one on stage is longer
/// and fills as its turn plays. Plain ink, thick enough to be found at a
/// glance and no louder than that.
class _PipsPainter extends CustomPainter {
  const _PipsPainter({
    required this.count,
    required this.frame,
    required this.show,
    required this.color,
  });

  final int count;
  final HeroFrame frame;

  /// How far in the pips are during the entrance, 0 to 1.
  final double show;
  final Color color;

  static const double _thick = 5;
  static const double _long = 26;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (show <= 0) return;
    final grow = AppCurves.easeOut.transform(frame.cardEnter);
    final leaving = frame.previous?.index;
    final top = (size.height - _thick) / 2;
    final track = Paint()..color = color.withValues(alpha: 0.3 * show);
    final fill = Paint()..color = color.withValues(alpha: 0.82 * show);

    var x = 0.0;
    for (var i = 0; i < count; i++) {
      final isActive = i == frame.activeIndex;
      // The pip of the benefit that just left shortens as the new one
      // lengthens, so the row keeps its width.
      final stretch = isActive
          ? (leaving == null || leaving == i ? 1.0 : grow)
          : (i == leaving ? 1 - grow : 0.0);
      final width = _thick + (_long - _thick) * stretch;
      final pip = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, width, _thick),
        const Radius.circular(_thick),
      );
      canvas.drawRRect(pip, track);
      if (isActive) {
        canvas
          ..save()
          ..clipRRect(pip)
          ..drawRect(
            Rect.fromLTWH(x, top, width * frame.progress, _thick),
            fill,
          )
          ..restore();
      }
      x += width + _gap;
    }
  }

  @override
  bool shouldRepaint(_PipsPainter old) =>
      count != old.count ||
      show != old.show ||
      color != old.color ||
      frame.activeIndex != old.frame.activeIndex ||
      frame.previous?.index != old.frame.previous?.index ||
      frame.cardEnter != old.frame.cardEnter ||
      frame.progress != old.frame.progress;
}

/// Brings one part of the words up into place during the entrance, each a
/// little after the one above it.
class _Rise extends StatelessWidget {
  const _Rise({required this.clock, required this.index, required this.child});

  final PaywallClock clock;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => PaywallClockBuilder(
    clock: clock,
    builder: (context, t, child) {
      final p = AppCurves.easeOut.transform(
        phase(stagger(index, t, each: 0.06, start: 0.3), 0, 0.36),
      );
      return Opacity(
        opacity: p,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - p)),
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// One benefit as a plain line: a small filled check and the words. The
/// line of the benefit on the stage is the strong one. A tap on it puts
/// its benefit on the stage.
class _Line extends StatelessWidget {
  const _Line({
    required this.clock,
    required this.frameAt,
    required this.index,
    required this.text,
    required this.label,
    required this.onTap,
    required this.sizes,
    required this.strong,
    required this.quiet,
  });

  final PaywallClock clock;
  final HeroFrame Function(double t) frameAt;
  final int index;
  final String text;
  final String? label;

  /// Null for the one line of a product with one benefit: nothing to pick.
  final VoidCallback? onTap;
  final _Sizes sizes;
  final TextStyle strong;
  final TextStyle quiet;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PaywallClockBuilder(
      clock: clock,
      builder: (context, t, check) {
        final frame = frameAt(t);
        final isActive = frame.activeIndex == index;
        // The check of the line that just took the stage pops once.
        final pop = isActive && frame.previous != null
            ? math.sin(math.pi * phase(frame.sceneSeconds, 0, 0.34))
            : 0.0;
        return Semantics(
          label: label == null ? text : '$text. $label',
          button: onTap != null,
          selected: onTap == null ? null : isActive,
          onTap: onTap,
          excludeSemantics: true,
          child: Row(
            children: [
              Transform.scale(scale: 1 + 0.22 * pop, child: check),
              const SizedBox(width: _Sizes.checkGap),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: context.motion(AppDurations.base),
                  style: isActive ? strong : quiet,
                  child: Text(text),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: sizes.check,
        height: sizes.check,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.highlight,
        ),
        alignment: Alignment.center,
        child: AppGlyph(
          GlyphType.check,
          size: sizes.check * 0.56,
          color: colors.onHighlight,
          strokeWidth: 3.4,
        ),
      ),
    );
  }
}
