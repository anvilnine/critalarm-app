import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_measure.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/layouts/reel/reel_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The one short line a scene says for [benefit], in display type.
String reelHeadlineFor(PaywallBenefit benefit) {
  final key = switch (benefit.id) {
    PaywallBenefitId.topics => LocaleKeys.paywall_reel_headlines_topics,
    PaywallBenefitId.pushes => LocaleKeys.paywall_reel_headlines_pushes,
    PaywallBenefitId.history => LocaleKeys.paywall_reel_headlines_history,
    PaywallBenefitId.widgets => LocaleKeys.paywall_reel_headlines_widgets,
    PaywallBenefitId.appIcons => LocaleKeys.paywall_reel_headlines_app_icons,
    PaywallBenefitId.wakeUpChallenges =>
      LocaleKeys.paywall_reel_headlines_wake_up_challenges,
    PaywallBenefitId.reliabilityChecks =>
      LocaleKeys.paywall_reel_headlines_reliability_checks,
    PaywallBenefitId.customSounds =>
      LocaleKeys.paywall_reel_headlines_custom_sounds,
    PaywallBenefitId.customAlarmScreens =>
      LocaleKeys.paywall_reel_headlines_custom_alarm_screens,
  };
  return key.tr(namedArgs: HostedBenefit.args);
}

/// The colours of one [ReelTone] in the current theme.
@immutable
class ReelToneColors {
  const ReelToneColors({
    required this.background,
    required this.ink,
    required this.muted,
  });

  factory ReelToneColors.of(BuildContext context, ReelTone tone) {
    final c = context.appColors;
    return switch (tone) {
      ReelTone.cream => ReelToneColors(
        background: c.cream,
        ink: c.ink,
        muted: c.ink2,
      ),
      ReelTone.high => ReelToneColors(
        background: c.highCanvas,
        ink: c.onCanvas,
        muted: c.onCanvasMuted,
      ),
      ReelTone.panel => ReelToneColors(
        background: c.panel,
        ink: c.onPanel,
        muted: c.onPanelMuted,
      ),
      ReelTone.surface => ReelToneColors(
        background: c.surface,
        ink: c.ink,
        muted: c.ink2,
      ),
      ReelTone.canvas => ReelToneColors(
        background: c.canvas,
        ink: c.onCanvas,
        muted: c.onCanvasMuted,
      ),
    };
  }

  final Color background;
  final Color ink;
  final Color muted;
}

/// The reel: one scene per benefit, edge to edge above the buy block, with
/// story bars along the top that fill as each turn plays.
///
/// Every scene has a tone of its own, a headline in display type, and the
/// kit's stage under it: the mascot reacting and the benefit's preview
/// playing large. One scene pushes the next out.
///
/// The hand: a tap on the right half goes to the next scene, on the left
/// half to the previous one, a sideways swipe does the same, and a finger
/// held down pauses the reel until it lifts.
class ReelComposition extends StatefulWidget {
  const ReelComposition({required this.scope, super.key});

  final PaywallLayoutScope scope;

  @override
  State<ReelComposition> createState() => _ReelCompositionState();
}

class _ReelCompositionState extends State<ReelComposition> {
  late final HeroPlayer _player = HeroPlayer(clock: widget.scope.clock);

  /// When the finger on the scene went down, and how long the last one
  /// stayed.
  Duration _downAt = Duration.zero;
  Duration _held = Duration.zero;

  /// How far the drag under way has moved, to tell a tap at the screen's
  /// edge, which the drag takes, from a drag.
  double _dragged = 0;

  PaywallLayoutScope get scope => widget.scope;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    _downAt = event.timeStamp;
    _held = Duration.zero;
    _player.fingerDown(event);
  }

  void _up(PointerEvent event) {
    _held = event.timeStamp - _downAt;
    _player.fingerUp(event);
  }

  void _tap(double x) {
    if (reelIsHold(_held)) return;
    _player.touch(step: reelTapStep(x, scope.size.width));
  }

  void _dragEnd(DragEndDetails details) {
    final wasTap = _dragged.abs() < kTouchSlop;
    _dragged = 0;
    _player.dragEnd(details);
    // The edge strip is the left half: a tap there is the previous scene.
    if (wasTap && !reelIsHold(_held)) _player.touch(step: -1);
  }

  @override
  Widget build(BuildContext context) {
    final sizes = ReelSizes.of(isCompact: scope.isCompact);
    final benefits = scope.benefits;
    final headlines = [for (final b in benefits) reelHeadlineFor(b)];
    final eyebrow = LocaleKeys.paywall_reel_eyebrow.tr(
      namedArgs: {
        'name': scope.isHosted
            ? LocaleKeys.paywall_kit_name_hosted.tr()
            : LocaleKeys.paywall_kit_name_pro.tr(),
      },
    );
    final width = scope.size.width - heroSideInset * 2;
    // Colour is set per scene.
    final headlineStyle = AppTypography.headline(
      const Color(0x00000000),
      fontSize: sizes.headline,
    );
    final eyebrowStyle = AppTypography.label(
      const Color(0x00000000),
      fontSize: 12,
    );
    // Every scene keeps the room of the tallest headline, so the stage
    // stands in one place from scene to scene.
    final words =
        paywallTextHeight(context, eyebrow, eyebrowStyle, width) +
        sizes.eyebrowGap +
        headlines.fold<double>(
          0,
          (tallest, line) => math.max(
            tallest,
            paywallTextHeight(context, line, headlineStyle, width),
          ),
        );
    final stage = Size(
      scope.size.width,
      reelStageHeight(height: scope.size.height, words: words, sizes: sizes),
    );
    // The frame's safe area has taken the status bar out of the media
    // query, so its height is read from the view: the scene runs under it.
    final view = View.of(context);
    final bleedTop = view.viewPadding.top / view.devicePixelRatio;
    final chip = PaywallToneColors.of(context, PaywallTone.canvas).background;

    final player = _player
      ..clock = scope.clock
      ..loop = HeroLoop([
        for (final b in benefits) b.previewId,
      ], holdSeconds: reelHoldSeconds);

    Widget panel(
      HeroFrame frame,
      double t, {
      required bool isLeaving,
      required double pull,
    }) {
      final index = frame.activeIndex;
      final tone = reelToneFor(index);
      final colors = ReelToneColors.of(context, tone);
      return _ReelPanel(
        colors: colors,
        top: bleedTop + reelBarsHeight,
        words: words,
        sizes: sizes,
        eyebrow: Text(
          eyebrow,
          style: eyebrowStyle.copyWith(color: colors.muted),
        ),
        headline: Text(
          headlines[index],
          style: headlineStyle.copyWith(color: colors.ink),
        ),
        rise: isLeaving ? null : scope.clock,
        pull: pull,
        stage: HeroStage(
          size: stage,
          frame: frame,
          seconds: player.stageSeconds(t),
          tone: reelAirFor(tone),
        ),
      );
    }

    // "2 of 4" for the scene at [index], wrapping at both ends.
    String position(int index) => LocaleKeys.paywall_reel_position.tr(
      namedArgs: {
        'current': '${index % benefits.length + 1}',
        'total': '${benefits.length}',
      },
    );

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => Semantics(
        container: true,
        label: '$eyebrow. ${headlines[player.frame.activeIndex]}',
        value: position(player.frame.activeIndex),
        increasedValue: position(player.frame.activeIndex + 1),
        decreasedValue: position(player.frame.activeIndex - 1),
        onIncrease: () => player.touch(step: 1),
        onDecrease: () => player.touch(step: -1),
        child: Listener(
          onPointerDown: _down,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            gestures: {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    TapGestureRecognizer.new,
                    (tap) =>
                        tap.onTapUp = (details) =>
                            _tap(details.localPosition.dx),
                  ),
              HeroStageDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<HeroStageDragRecognizer>(
                    HeroStageDragRecognizer.new,
                    (drag) => drag
                      ..onStart = player.dragStart
                      ..onUpdate = (details) {
                        _dragged += details.primaryDelta ?? 0;
                        player.dragUpdate(details);
                      }
                      ..onEnd = _dragEnd
                      ..onCancel = player.dragCancel,
                  ),
            },
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: PaywallClockBuilder(
                  clock: scope.clock,
                  builder: (context, t, _) {
                    final frame = player.frameAt(t);
                    final leaving = reelLeaving(frame);
                    final eased = AppCurves.easeOut.transform(frame.cardEnter);
                    final push = leaving == null
                        ? const ReelPush(into: 0, out: 0)
                        : reelPushAt(eased, frame.direction);
                    final ink = ReelToneColors.of(
                      context,
                      reelToneFor(frame.activeIndex),
                    ).ink;
                    final barInk = leaving == null
                        ? ink
                        : Color.lerp(
                            ReelToneColors.of(
                              context,
                              reelToneFor(leaving.activeIndex),
                            ).ink,
                            ink,
                            eased,
                          )!;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The scenes run up under the status bar and end
                        // on the buy block with a round lower edge.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: -bleedTop,
                          bottom: reelSceneGap,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(Radii.xl),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (leaving != null)
                                  Transform.translate(
                                    key: ValueKey(frame.previousTurn),
                                    offset: Offset(
                                      push.out * scope.size.width,
                                      0,
                                    ),
                                    child: panel(
                                      leaving,
                                      t,
                                      isLeaving: true,
                                      // It leaves from where the finger
                                      // let go of it.
                                      pull: frame.pull * (1 - eased),
                                    ),
                                  ),
                                Transform.translate(
                                  key: ValueKey(frame.turn),
                                  offset: Offset(
                                    push.into * scope.size.width,
                                    0,
                                  ),
                                  child: panel(
                                    reelSettled(frame),
                                    t,
                                    isLeaving: false,
                                    pull: player.pullAt(t),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: heroSideInset,
                          right: reelCrossRoom,
                          top: 0,
                          height: reelBarsHeight,
                          child: CustomPaint(
                            painter: ReelBarsPainter(
                              count: benefits.length,
                              active: frame.activeIndex,
                              progress: frame.progress,
                              show: player.isStill
                                  ? 1
                                  : phase(t, 0.2, heroEntranceSeconds * 0.7),
                              color: barInk,
                            ),
                          ),
                        ),
                        // The cross is the frame's, in the frame's ink. A
                        // disc of the frame's own ground keeps it readable
                        // on every scene.
                        Positioned(
                          top: (reelBarsHeight - _chip) / 2,
                          right:
                              PaywallLayoutScope.closeCrossInset +
                              (AppDismissCross.hitSize - _chip) / 2,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: chip,
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(dimension: _chip),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _chip = 30;

/// One scene: its ground, its words, and the stage under them.
class _ReelPanel extends StatelessWidget {
  const _ReelPanel({
    required this.colors,
    required this.top,
    required this.words,
    required this.sizes,
    required this.eyebrow,
    required this.headline,
    required this.stage,
    required this.rise,
    required this.pull,
  });

  final ReelToneColors colors;

  /// Where the words start: under the status bar and the story bars.
  final double top;

  /// The room the words keep.
  final double words;
  final ReelSizes sizes;
  final Widget eyebrow;
  final Widget headline;
  final Widget stage;

  /// The clock the words rise on during the entrance. Null for a scene on
  /// its way out, whose words are already there.
  final PaywallClock? rise;

  /// How far the finger holds the scene's content off its place, in
  /// points. The ground stays where it is.
  final double pull;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        eyebrow,
        SizedBox(height: sizes.eyebrowGap),
        headline,
      ],
    );
    final clock = rise;
    return ColoredBox(
      color: colors.background,
      child: Transform.translate(
        offset: Offset(pull, 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The stage first, so its disc never paints over the words.
            Positioned(
              left: 0,
              top: top + words + sizes.stageGap,
              child: stage,
            ),
            Positioned(
              left: heroSideInset,
              right: heroSideInset,
              top: top,
              child: clock == null
                  ? text
                  : HeroRise(clock: clock, index: 0, child: text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the story bars for one frame: one bar per scene across the whole
/// width, the scenes already seen full, the one playing filling.
class ReelBarsPainter extends CustomPainter {
  const ReelBarsPainter({
    required this.count,
    required this.active,
    required this.progress,
    required this.show,
    required this.color,
  });

  final int count;
  final int active;
  final double progress;

  /// How far in the bars are during the entrance, 0 to 1.
  final double show;

  /// The ink of the scene they lie on.
  final Color color;

  static const double _thick = 4;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (show <= 0 || count == 0) return;
    final each = (size.width - _gap * (count - 1)) / count;
    final top = (size.height - _thick) / 2;
    final track = Paint()..color = color.withValues(alpha: 0.24 * show);
    final fill = Paint()..color = color.withValues(alpha: 0.92 * show);
    for (var i = 0; i < count; i++) {
      final left = i * (each + _gap);
      final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, each, _thick),
        const Radius.circular(_thick),
      );
      canvas.drawRRect(bar, track);
      final full = reelBarFill(i, active: active, progress: progress);
      if (full <= 0) continue;
      canvas
        ..save()
        ..clipRRect(bar)
        ..drawRect(Rect.fromLTWH(left, top, each * full, _thick), fill)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(ReelBarsPainter old) =>
      count != old.count ||
      active != old.active ||
      progress != old.progress ||
      show != old.show ||
      color != old.color;
}
