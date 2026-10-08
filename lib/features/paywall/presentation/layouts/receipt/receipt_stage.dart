import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_score.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_measure.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_paper.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the slip prints for [benefit]: a few words that fit one line of
/// the mono face.
String receiptLineFor(PaywallBenefit benefit) {
  final key = switch (benefit.id) {
    PaywallBenefitId.topics => LocaleKeys.paywall_receipt_lines_topics,
    PaywallBenefitId.pushes => LocaleKeys.paywall_receipt_lines_pushes,
    PaywallBenefitId.history => LocaleKeys.paywall_receipt_lines_history,
    PaywallBenefitId.widgets => LocaleKeys.paywall_receipt_lines_widgets,
    PaywallBenefitId.appIcons => LocaleKeys.paywall_receipt_lines_app_icons,
    PaywallBenefitId.wakeUpChallenges =>
      LocaleKeys.paywall_receipt_lines_wake_up_challenges,
    PaywallBenefitId.reliabilityChecks =>
      LocaleKeys.paywall_receipt_lines_reliability_checks,
    PaywallBenefitId.customSounds =>
      LocaleKeys.paywall_receipt_lines_custom_sounds,
    PaywallBenefitId.customAlarmScreens =>
      LocaleKeys.paywall_receipt_lines_custom_alarm_screens,
  };
  return key.tr(namedArgs: HostedBenefit.args);
}

/// The receipt: a slot with the printed slip hanging from it, the mascot
/// large beside it, and under the mascot the preview of the line being
/// played, whole and clear of the paper. Under the stage, the pips, a
/// headline, and one quiet sentence about that line.
///
/// The slip is the benefit list, so there are no check lines. A tap on a
/// line of the slip puts that benefit on, a swipe across the stage goes to
/// the next or the previous one, and a tap anywhere else on the stage
/// plays the current one again.
class ReceiptComposition extends StatefulWidget {
  const ReceiptComposition({required this.scope, super.key});

  final PaywallLayoutScope scope;

  @override
  State<ReceiptComposition> createState() => _ReceiptCompositionState();
}

class _ReceiptCompositionState extends State<ReceiptComposition> {
  late final HeroPlayer _player = HeroPlayer(clock: widget.scope.clock)
    ..addListener(_onPlayer);

  ReceiptPlan? _plan;

  PaywallLayoutScope get scope => widget.scope;

  // A choice of the hand redraws the words: when nothing may move no clock
  // ticks to do it.
  void _onPlayer() => setState(() {});

  @override
  void dispose() {
    _player
      ..removeListener(_onPlayer)
      ..dispose();
    super.dispose();
  }

  void _tapUp(TapUpDetails details) {
    final row = _plan?.rowAt(details.localPosition);
    if (row == null) return _player.touch();
    _player.touch(index: row);
  }

  @override
  Widget build(BuildContext context) {
    final tones = PaywallToneColors.of(context, PaywallTone.canvas);
    final sizes = HeroSizes.of(isCompact: scope.isCompact);
    final benefits = scope.benefits;
    final count = benefits.length;
    final width = scope.size.width - heroSideInset * 2;
    final name = scope.isHosted
        ? LocaleKeys.paywall_kit_name_hosted.tr()
        : LocaleKeys.paywall_kit_name_pro.tr();
    final price = context.select<PaywallBuyCubit, String?>(
      (cubit) => cubit.state.selected?.price,
    );

    final headline = LocaleKeys.paywall_receipt_headline.tr(
      namedArgs: {'name': name},
    );
    final headlineStyle = AppTypography.headline(
      tones.ink,
      fontSize: sizes.headline,
    );
    final sentenceStyle = AppTypography.small(
      tones.muted,
      fontSize: sizes.line,
    ).copyWith(height: 1.35);
    final headlineHeight = paywallTextHeight(
      context,
      headline,
      headlineStyle,
      width,
    );
    // The sentence keeps the room of the longest one, so nothing moves as
    // the stage plays.
    final tallest = benefits.fold<double>(
      0,
      (most, b) => math.max(
        most,
        paywallTextHeight(context, b.line, sentenceStyle, width),
      ),
    );

    HeroStageRoom roomFor(double words) => heroStageRoomFor(
      height: scope.size.height,
      words: words,
      gap: sizes.stageGap,
      bottomGap: sizes.bottomGap,
      stageMax: ReceiptPlan.maxHeight(count),
    );
    const sentenceGap = Spacing.s1 + 2;
    var room = roomFor(headlineHeight + sentenceGap + tallest);
    // At a large text size the sentence goes before the slip does.
    final hasSentence = room.stage >= ReceiptPlan.minHeight(count);
    if (!hasSentence) room = roomFor(headlineHeight);
    final stage = Size(
      scope.size.width,
      math.max(room.stage, ReceiptPlan.minHeight(count)),
    );
    final plan = _plan = ReceiptPlan.of(stage, count: count);

    final player = _player
      ..clock = scope.clock
      ..loop = HeroLoop([
        for (final b in benefits) b.previewId,
      ], prelude: ReceiptTimeline.prelude);

    final lines = [
      for (final (i, b) in benefits.indexed)
        ReceiptLine(
          text: receiptLineFor(b),
          label: b.line,
          onTap: () => player.touch(index: i),
        ),
    ];
    // The frame's safe area has taken the status bar out of the media
    // query, so its height is read from the view: the air runs under it.
    final view = View.of(context);
    final bleedTop = view.viewPadding.top / view.devicePixelRatio;

    return PaywallCueScore(
      clock: scope.clock,
      // The print is heard a line at a time, then the stamp, then the
      // first preview coming out.
      beats: receiptCues(count),
      player: player,
      turnCue: PaywallCue.next,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Listener(
              onPointerDown: player.fingerDown,
              onPointerUp: player.fingerUp,
              onPointerCancel: player.fingerUp,
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                gestures: {
                  TapGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        TapGestureRecognizer
                      >(
                        TapGestureRecognizer.new,
                        (tap) => tap.onTapUp = _tapUp,
                      ),
                  HeroStageDragRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        HeroStageDragRecognizer
                      >(
                        HeroStageDragRecognizer.new,
                        (drag) => drag
                          ..onStart = player.dragStart
                          ..onUpdate = player.dragUpdate
                          ..onEnd = player.dragEnd
                          ..onCancel = player.dragCancel,
                      ),
                },
                child: RepaintBoundary(
                  child: PaywallClockBuilder(
                    clock: scope.clock,
                    builder: (context, t, _) => _ReceiptStage(
                      plan: plan,
                      player: player,
                      t: t,
                      bleedTop: bleedTop,
                      title: LocaleKeys.app_title.tr(),
                      lines: lines,
                      name: name,
                      price: price,
                      followsIntro: scope.followsIntro,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: room.gap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: heroSideInset),
                child: HeroPips(player: player, count: count, color: tones.ink),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: heroSideInset,
                right: heroSideInset,
                bottom: room.under,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeroRise(
                    clock: scope.clock,
                    index: 0,
                    child: Semantics(
                      header: true,
                      child: Text(headline, style: headlineStyle),
                    ),
                  ),
                  if (hasSentence) ...[
                    const SizedBox(height: sentenceGap),
                    HeroRise(
                      clock: scope.clock,
                      index: 1,
                      child: SizedBox(
                        height: tallest,
                        // The slip's lines say the same to a screen reader.
                        child: ExcludeSemantics(
                          child: PaywallClockBuilder(
                            clock: scope.clock,
                            builder: (context, t, _) {
                              final active = player.frameAt(t).activeIndex;
                              return AnimatedSwitcher(
                                duration: context.motion(AppDurations.base),
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topLeft,
                                  children: [...previous, ?current],
                                ),
                                child: Align(
                                  key: ValueKey(active),
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    benefits[active % count].line,
                                    style: sentenceStyle,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One frame of the stage: the air, the card beside the paper, the paper
/// hanging from the slot, and the mascot in front.
class _ReceiptStage extends StatelessWidget {
  const _ReceiptStage({
    required this.plan,
    required this.player,
    required this.t,
    required this.bleedTop,
    required this.title,
    required this.lines,
    required this.name,
    required this.price,
    required this.followsIntro,
  });

  final ReceiptPlan plan;
  final HeroPlayer player;
  final double t;
  final double bleedTop;
  final String title;
  final List<ReceiptLine> lines;
  final String name;
  final String? price;

  /// True when an intro handed over to this layout.
  final bool followsIntro;

  /// One preview at the card's size, lifted off the stage.
  Widget _card(
    PaywallPreviewId preview, {
    required Key key,
    required double? playFrom,
    required BorderRadius radius,
    required bool isDark,
  }) => DecoratedBox(
    key: key,
    decoration: BoxDecoration(
      borderRadius: radius,
      boxShadow: AppShadows.shadowMd(isDark: isDark),
    ),
    child: PaywallPreview(
      preview,
      sizeClass: PaywallPreviewClass.medium,
      size: plan.card.size,
      playFrom: playFrom,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final inks = ReceiptInks.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final air = HeroAtmosphereColors.of(context, PaywallTone.canvas);
    final frame = player.frameAt(t);
    // The print plays once. After it, and when nothing may move, the slip
    // is whole and the loop has the stage.
    final isPrinting = !player.isStill && t < ReceiptTimeline.restAt;
    final steps = plan.stops.length;
    final focus = plan.column.center;

    final Widget mascot;
    if (isPrinting) {
      final actor = ReceiptTimeline.actor(
        t,
        count: plan.count,
        followsIntro: followsIntro,
      );
      mascot = HeroMascot(
        size: plan.mascot.width,
        entranceStyle: receiptMotion.entrance,
        face: actor.face,
        fromFace: actor.fromFace,
        faceBlend: actor.faceBlend,
        hop: actor.hop,
        entrance: actor.entrance,
      );
    } else {
      mascot = HeroMascot.frame(
        frame,
        size: plan.mascot.width,
        motion: receiptMotion,
      );
    }

    // The card: out from behind the paper at the end of the print. After
    // that one preview slides out as the next slides in, and the paper is
    // in front of whichever of the two is on its side.
    final visible = plan.cardTravel;
    final previous = isPrinting ? null : frame.previous;
    final change = heroCardArrivalPose(
      receiptMotion.arrival,
      previous == null ? 1 : frame.cardEnter,
      width: plan.card.width,
      direction: receiptCardWay(frame.direction),
      pull: frame.pull * 0.4,
    );
    final confetti = receiptConfettiSeconds(t, isStill: player.isStill);
    final cardShown = isPrinting
        ? phase(
            t,
            ReceiptTimeline.peekStart,
            ReceiptTimeline.peekStart + 0.08,
          )
        : 1.0;
    final cardRadius = BorderRadius.circular(
      extrasPreviewRadius(plan.card.shortestSide),
    );

    return SizedBox.fromSize(
      size: plan.stage,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: -bleedTop,
            bottom: 0,
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: HeroAtmospherePainter(
                  focus: focus.translate(0, bleedTop),
                  radius: math.min(
                    plan.column.longestSide * 0.6,
                    plan.stage.height - focus.dy,
                  ),
                  seconds: player.stageSeconds(t),
                  entrance: player.isStill ? 1 : heroEntranceAt(t),
                  showsShapes: true,
                  disc: air.disc,
                  soft: air.soft,
                  strong: air.strong,
                  light: air.light,
                ),
              ),
            ),
          ),
          // The confetti the stamp throws, in the column beside the paper.
          if (confetti != null)
            Positioned(
              left: plan.paper.right - ReceiptPlan.cardGap,
              right: 0,
              top: -bleedTop,
              bottom: 0,
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: HeroAtmospherePainter(
                    focus: Offset.zero,
                    radius: 0,
                    seconds: confetti,
                    entrance: 1,
                    showsShapes: true,
                    disc: air.disc.withValues(alpha: 0),
                    soft: air.soft,
                    strong: air.strong,
                    light: air.light,
                    style: receiptMotion.atmosphere,
                  ),
                ),
              ),
            ),
          if (previous?.preview != null && frame.cardEnter < 1)
            Positioned.fromRect(
              rect: plan.card,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: change.outgoing.opacity,
                  child: Transform.translate(
                    offset: Offset(change.outgoing.dx, 0),
                    child: _card(
                      previous!.preview!,
                      key: ValueKey(frame.previousTurn),
                      playFrom: frame.previousPlayFrom,
                      radius: cardRadius,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            ),
          if (cardShown > 0 && frame.scene?.preview != null)
            Positioned.fromRect(
              rect: plan.card,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: cardShown * change.incoming.opacity,
                  child: Transform.translate(
                    offset: Offset(
                      isPrinting
                          ? -visible * (1 - ReceiptTimeline.peek(t))
                          : math.max(
                              -visible,
                              change.incoming.dx + player.pullAt(t) * 0.4,
                            ),
                      0,
                    ),
                    child: _card(
                      frame.scene!.preview!,
                      key: ValueKey(frame.turn),
                      playFrom: frame.playFrom,
                      radius: cardRadius,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fromRect(
            rect: plan.paper,
            child: Transform.rotate(
              angle: isPrinting ? ReceiptTimeline.sway(t) : 0,
              alignment: Alignment.topCenter,
              child: ReceiptPaper(
                plan: plan,
                title: title,
                lines: lines,
                name: name,
                price: price,
                stampText: name,
                active: frame.activeIndex,
                out: isPrinting ? ReceiptTimeline.feed(t, plan.stops) : null,
                inks: isPrinting
                    ? [
                        for (var i = 0; i < steps; i++)
                          ReceiptTimeline.ink(t, i, steps),
                      ]
                    : null,
                marker: isPrinting
                    ? phase(
                        t,
                        ReceiptTimeline.peekStart,
                        ReceiptTimeline.restAt,
                      )
                    : 1,
                stamp: isPrinting
                    ? ReceiptTimeline.stamp(t)
                    : const ReceiptStamp(
                        opacity: 1,
                        scale: 1,
                        angle: ReceiptTimeline.stampAngle,
                      ),
              ),
            ),
          ),
          // The slot, over the top of the paper.
          Positioned.fromRect(
            rect: plan.slot,
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: inks.slot,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  boxShadow: AppShadows.shadowSm(isDark: isDark),
                ),
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.9,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: inks.slit,
                        borderRadius: BorderRadius.circular(Radii.xs),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: plan.mascot,
            child: ExcludeSemantics(child: mascot),
          ),
        ],
      ),
    );
  }
}
