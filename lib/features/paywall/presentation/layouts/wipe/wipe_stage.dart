import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_score.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_rules.dart';
import 'package:flutter/material.dart';

/// The kit's stage drawn twice in one box and split by a divider. Left of
/// it is Free: the same scene with the colour taken out, the preview held
/// on what Free has, the mascot doubtful. Right of it is the product,
/// playing as the approved stage does. Both are drawn from one frame in
/// one arrangement, so they meet exactly wherever the divider stands, and
/// the mascot is one character with the line across its face.
///
/// Bubbles rise on the product's side only. When the mascot leans toward
/// the product the divider goes with it, so the line stays on its face.
///
/// A sideways drag anywhere on the stage moves the divider. A tap plays
/// the current turn again, and the loop waits under a finger.
class WipeStage extends StatefulWidget {
  const WipeStage({
    required this.player,
    required this.size,
    required this.before,
    required this.after,
    required this.label,
    required this.showing,
    this.lead = 0,
    super.key,
  });

  /// The head start of the sweep after an intro. See `wipeLeadFor`.
  final double lead;

  final HeroPlayer player;
  final Size size;

  /// The tags of the two sides: Free, and the product's name.
  final String before;
  final String after;

  /// What a screen reader calls the divider, and what it says the stage
  /// shows at a frame.
  final String label;
  final String? Function(HeroFrame frame) showing;

  @override
  State<WipeStage> createState() => _WipeStageState();
}

class _WipeStageState extends State<WipeStage> {
  static const double _tagGap = 10;
  static const double _tagTop = 2;

  /// The least room a tag keeps from the screen's edge.
  static const double _tagEdge = 8;
  static const double _fade = 44;
  static const double _grip = 36;

  /// Kept clear at the right for the frame's close cross.
  static const double _crossRoom =
      PaywallLayoutScope.closeCrossSize + PaywallLayoutScope.closeCrossInset;

  final PaywallClock _frozen = const _FrozenClock();

  WipeGrip? _hand;
  double _settle = wipeSettleAlone;

  HeroPlayer get _player => widget.player;

  double _at(double t) => wipeDividerAt(
    t,
    settle: _settle,
    grip: _hand,
    isStill: _player.isStill,
    lead: widget.lead,
  );

  // A finger takes hold of the divider: one tick of the ratchet.
  void _grab(DragStartDetails details) {
    playPaywallCue(PaywallCue.ratchet);
    setState(() {
      _hand = WipeGrip(
        at: _at(_player.clock.value).clamp(wipeMin, wipeMax),
      );
    });
  }

  void _drag(DragUpdateDetails details) {
    final hand = _hand;
    if (hand == null || widget.size.width <= 0) return;
    final moved = hand.moved((details.primaryDelta ?? 0) / widget.size.width);
    // A tick at every tenth of the width, a knock at either stop.
    final cue = wipeDragCue(hand.at, moved.at);
    if (cue != null) playPaywallCue(cue);
    setState(() => _hand = moved);
  }

  // The finger lets go and the divider stays where it was left.
  void _letGo() {
    final hand = _hand;
    if (hand == null || hand.releasedAt != null) return;
    playPaywallCue(PaywallCue.snap);
    setState(() => _hand = hand.released(_player.clock.value));
  }

  /// A screen reader moves the divider a tenth of the stage at a time.
  void _nudge(double by) {
    final at = _at(_player.clock.value).clamp(wipeMin, wipeMax);
    final moved = WipeGrip(at: at).moved(by);
    final cue = wipeDragCue(at, moved.at);
    if (cue != null) playPaywallCue(cue);
    setState(() => _hand = moved.released(_player.clock.value));
  }

  String _share(double at) =>
      '${((1 - at.clamp(wipeMin, wipeMax)) * 100).round()}%';

  double _widthOf(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final scope = PaywallLayoutScope.of(context);
    final colors = context.appColors;
    final tones = PaywallToneColors.of(context, PaywallTone.canvas);
    final arrangement = wipeArrangementFor(size);

    // No room for a face: nothing to compare, so the stage is the kit's.
    if (arrangement.kind == HeroStageKind.none) {
      return HeroLiveStage(
        player: _player,
        size: size,
        label: widget.showing,
        arrange: wipeArrangementFor,
        motion: wipeMotion,
      );
    }

    _settle = wipeSettleFor(arrangement, size.width);
    final gripY = wipeGripCentreFor(arrangement, size);

    // The frame's safe area has taken the status bar out of the media
    // query, so its height is read from the view: both sides run under it.
    final view = View.of(context);
    final bleed = view.viewPadding.top / view.devicePixelRatio;

    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final tagStyle = AppTypography.label(tones.ink, fontSize: 12);
    final beforeWidth = _widthOf(widget.before, tagStyle, scaler);
    final afterWidth = _widthOf(widget.after, tagStyle, scaler);

    // The Free side has a clock of its own that stands still, so its
    // preview holds one moment whatever the layout's clock does.
    final frozenScope = PaywallLayoutScope(
      product: scope.product,
      benefits: scope.benefits,
      size: scope.size,
      isCompact: scope.isCompact,
      source: scope.source,
      clock: _frozen,
      closeOnLeft: scope.closeOnLeft,
      close: scope.close,
    );
    final media = MediaQuery.of(context).copyWith(disableAnimations: false);
    final muted = ColorFilter.matrix(wipeMutedMatrix(wipeFreeSaturation));
    final full = size.height + bleed;
    final fadeFrom = full <= 0 ? 0.0 : (1 - _fade / full).clamp(0.0, 1.0);
    final tail = [tones.ink, tones.ink, tones.ink.withValues(alpha: 0)];
    final tailStops = [0.0, fadeFrom, 1.0];
    // On the dark canvas the two sides are nearly one black, so the
    // product's side gets a wash of the yellow. The Free side is drawn
    // over it and keeps none.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wash = colors.yellow.withValues(alpha: isDark ? 0.14 : 0);
    final lead = widget.lead;

    return PaywallCueScore(
      clock: _player.clock,
      // A divider the hand has taken does not sweep in.
      beats: _hand == null ? wipeSweepCues(lead: lead) : const [],
      child: HeroTouchArea(
        player: _player,
        swipes: false,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          gestures: {
            HeroStageDragRecognizer:
                GestureRecognizerFactoryWithHandlers<HeroStageDragRecognizer>(
                  HeroStageDragRecognizer.new,
                  (drag) => drag
                    ..onStart = _grab
                    ..onUpdate = _drag
                    ..onEnd = ((_) => _letGo())
                    ..onCancel = _letGo,
                ),
          },
          child: RepaintBoundary(
            child: PaywallClockBuilder(
              clock: _player.clock,
              builder: (context, t, _) {
                final frame = _player.frameAt(t);
                final seconds = _player.stageSeconds(t);
                final isStill = _player.isStill;
                final home = _at(t);
                // Home on the mascot, the divider leans with it.
                final leans = !isStill && (home - _settle).abs() < 1e-6;
                final x =
                    home * size.width +
                    (leans
                        ? wipeLeanShiftAt(
                            frame.bob,
                            mascot: arrangement.mascot.width,
                          )
                        : 0);
                final at = size.width <= 0 ? home : x / size.width;
                // The line and its grip come in as the sweep starts, the
                // tags as it ends.
                final line = isStill || _hand != null
                    ? 1.0
                    : phase(
                        t + lead,
                        wipeSweepStart - 0.1,
                        wipeSweepStart + 0.1,
                      );
                final tags = isStill || _hand != null
                    ? 1.0
                    : phase(t + lead, wipeSweepEnd - 0.3, wipeSweepEnd);

                return Semantics(
                  container: true,
                  slider: true,
                  label: [widget.label, ?widget.showing(frame)].join('. '),
                  // How much of the stage is the product's.
                  value: _share(at),
                  increasedValue: _share(at - 0.1),
                  decreasedValue: _share(at + 0.1),
                  onIncrease: () => _nudge(-0.1),
                  onDecrease: () => _nudge(0.1),
                  child: ExcludeSemantics(
                    child: SizedBox.fromSize(
                      size: size,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (isDark)
                            Positioned(
                              left: 0,
                              top: -bleed,
                              width: size.width,
                              height: full,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      wash,
                                      wash,
                                      wash.withValues(alpha: 0),
                                    ],
                                    stops: tailStops,
                                  ),
                                ),
                              ),
                            ),
                          HeroStage(
                            size: size,
                            frame: frame,
                            seconds: seconds,
                            bleedTop: bleed,
                            arrange: wipeArrangementFor,
                            motion: wipeMotion,
                          ),
                          Positioned(
                            left: 0,
                            top: -bleed,
                            width: size.width,
                            height: full,
                            child: ClipRect(
                              clipper: _LeftOf(x),
                              child: ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (bounds) => LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: tail,
                                  stops: tailStops,
                                ).createShader(bounds),
                                child: ColorFiltered(
                                  colorFilter: muted,
                                  child: ColoredBox(
                                    color: tones.background,
                                    child: Padding(
                                      padding: EdgeInsets.only(top: bleed),
                                      child: MediaQuery(
                                        data: media,
                                        child: PaywallStill(
                                          isStill: false,
                                          child: PaywallLayoutScopeProvider(
                                            scope: frozenScope,
                                            child: HeroStage(
                                              size: size,
                                              frame: wipeFreeFrame(frame),
                                              seconds: seconds,
                                              bleedTop: bleed,
                                              arrange: wipeArrangementFor,
                                              // The disc alone: nothing
                                              // rises on this side.
                                              showsShapes: false,
                                              motion: wipeFreeMotion,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: x - 1,
                            top: -bleed,
                            width: 2,
                            height: full,
                            child: Opacity(
                              opacity: line,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: tail,
                                    stops: tailStops,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: size.width - x + _tagGap,
                            top: _tagTop,
                            child: Opacity(
                              opacity:
                                  tags *
                                  wipeTagShow(
                                    x - _tagEdge,
                                    beforeWidth + _tagGap,
                                  ),
                              child: Text(
                                widget.before,
                                style: tagStyle,
                                textScaler: scaler,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          Positioned(
                            left: x + _tagGap,
                            top: _tagTop,
                            child: Opacity(
                              opacity:
                                  tags *
                                  wipeTagShow(
                                    size.width - _crossRoom - x,
                                    afterWidth + _tagGap * 2,
                                  ),
                              child: Text(
                                widget.after,
                                style: tagStyle,
                                textScaler: scaler,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          Positioned(
                            left: x - _grip / 2,
                            top: gripY - _grip / 2,
                            child: Opacity(
                              opacity: line,
                              child: CustomPaint(
                                size: const Size.square(_grip),
                                painter: _GripPainter(
                                  fill: colors.cream,
                                  ink: colors.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps what is left of [x].
class _LeftOf extends CustomClipper<Rect> {
  const _LeftOf(this.x);

  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, x, size.height);

  @override
  bool shouldReclip(_LeftOf oldClipper) => x != oldClipper.x;
}

/// The round grip on the divider: a disc with an arrow head each way.
class _GripPainter extends CustomPainter {
  const _GripPainter({required this.fill, required this.ink});

  final Color fill;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawCircle(centre, radius - 1, Paint()..color = fill)
      ..drawCircle(centre, radius - 1, stroke);
    for (final side in const [-1.0, 1.0]) {
      final tip = centre.translate(side * radius * 0.5, 0);
      final back = side * radius * 0.24;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx - back, tip.dy - radius * 0.26)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - back, tip.dy + radius * 0.26),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_GripPainter old) => fill != old.fill || ink != old.ink;
}

/// A clock that stands on one second and is never still, so a preview
/// under it draws the moment it is cued to and nothing else.
class _FrozenClock implements PaywallClock {
  const _FrozenClock();

  @override
  double get value => wipeFrozenSecond;

  @override
  bool get isStill => false;

  @override
  void restart() {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
