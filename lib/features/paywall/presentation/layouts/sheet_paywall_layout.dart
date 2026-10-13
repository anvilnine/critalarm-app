import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_headline_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_page.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_plan.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The Sheet layout: a bottom sheet over the screen where the user hit a
/// limit. The row they tapped stays lit above the scrim, the mascot looks
/// over the sheet's top edge at it, and the sheet answers that one limit
/// first.
///
/// Inside the sheet it is the approved composition from the kit
/// (`HeroComposition`): the lead benefit's preview playing large, the
/// headline for the place the user came from, the benefits as plain lines
/// with the lead first, and the buy block. The loop, the swipes and the
/// taps are the kit's. Two things are this layout's own. The mascot
/// stands whole astride the sheet's top edge, beside the preview, and the
/// sheet's rise carries it up: its eyes come over the foot of the screen
/// first, and it hops as the sheet lands. And when the lead benefit has
/// done its job on the stage, the lit row above answers: the switch goes
/// on, or the lock on its badge becomes a check.
///
/// Past the default text size the words need the room the mascot's lower
/// half stands in. It then stands behind the sheet and looks over the
/// edge.
///
/// The screen behind is a picture, drawn from what opened the paywall. The
/// sheet holds a `PaywallFrameBody`, which stays in its seat from the first
/// frame so the close cross is always there.
class SheetPaywallLayout extends StatefulWidget {
  const SheetPaywallLayout({super.key});

  @override
  State<SheetPaywallLayout> createState() => _SheetPaywallLayoutState();
}

class _SheetPaywallLayoutState extends PaywallClockState<SheetPaywallLayout> {
  /// How far the white surface runs under the screen, so the bounce at the
  /// top of the rise never shows what is behind.
  static const double _underhang = 80;

  /// How far below its own height the sheet starts, at least. It starts
  /// far enough down that the mascot on its edge is off the screen too.
  static const double _extraTravel = 46;

  /// How far the drifting shapes keep from the sheet's top edge, from the
  /// pips under the stage, and from the right edge, where the cross is.
  static const double _airTop = 16;
  static const double _airBottom = 14;
  static const double _airRight = 30;

  late final _SheetClock _clock = _SheetClock(() => t);
  final PaywallFrameController _frame = PaywallFrameController();

  /// Plays the loop for the sheet and for what is drawn above it. It needs
  /// the frame's clock, so it is made when the frame first builds.
  HeroPlayer? _player;

  /// True once the buy block may come in.
  bool _buyIn = false;

  /// The loop as last built, for the cues.
  HeroLoop? _loop;

  /// The clock and the lit row's answer as the last tick saw them.
  double _seenAt = 0;
  double _seenProof = 0;
  bool _isMuted = false;

  @override
  double get restAt => SheetMotion.restAt;

  // Only what listens to the clock redraws on a tick.
  @override
  void onTick() {
    _clock.tell();
    if (!_buyIn && t >= SheetMotion.buyBlockAt) {
      setState(() => _buyIn = true);
    }
    _cue();
  }

  /// How long the intro before this sheet keeps its entrance quiet.
  double get _quietUntil {
    final play = PaywallIntroPlay.peek(context);
    if (play == null || play.intro == PaywallIntroId.none) return 0;
    return play.handle.quietFor;
  }

  // The moments that are heard: the sheet lands, and the lit row answers.
  // The frame plays the rise as the sheet appears, and the stage plays
  // the loop's own changes.
  void _cue() {
    final now = t;
    final was = _seenAt;
    _seenAt = now;
    final player = _player;
    final loop = _loop;
    final proof = player == null || loop == null
        ? 0.0
        : SheetMotion.proofFor(loop, player.frame);
    final wasProof = _seenProof;
    _seenProof = proof;
    if (_isMuted || isStill || now <= was) return;

    // The sheet lands and bumps the mascot into a hop.
    paywallCuesBetween(
      SheetMotion.cues,
      was,
      now,
      quietUntil: _quietUntil,
    ).forEach(playPaywallCue);
    // The lit row answers: the switch goes on, the lock becomes a check.
    // Heard the first time only, which is the loop's first pass.
    final answers = wasProof <= 0 && proof > 0;
    if (answers &&
        player != null &&
        loop != null &&
        paywallLoopCues(
          now,
          entranceEnd: loop.entranceEnd,
          period: loop.period,
          touched: player.hand != null,
        )) {
      playPaywallCue(PaywallCue.lift);
    }
  }

  // The plan needs the buy block's height, so it is drawn again when the
  // kit has laid the block out. Until then nothing is painted: the first
  // layout only measures.
  void _onBuyBlockHeight() => setState(() {});

  HeroPlayer _playerFor(PaywallLayoutScope scope) {
    final existing = _player;
    if (existing != null) return existing;
    final made = _player = HeroPlayer(clock: scope.clock);
    // The parts above the sheet are drawn from it on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    return made;
  }

  @override
  void initState() {
    super.initState();
    _frame.buyBlockHeight.addListener(_onBuyBlockHeight);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isMuted = PaywallMuted.of(context);
    _clock.tell();
  }

  @override
  void dispose() {
    _frame.buyBlockHeight.removeListener(_onBuyBlockHeight);
    _frame.dispose();
    _player?.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// The headline for [lead]. The topics lead may name the topic the person
  /// was making: see [_topicsHeadline].
  String? _headline(
    BuildContext context,
    PaywallBenefit? lead,
    PaywallOffer offer,
  ) {
    if (lead?.id == PaywallBenefitId.topics) {
      return _topicsHeadline(context, offer);
    }
    final key = switch (lead?.id) {
      PaywallBenefitId.topics => LocaleKeys.paywall_sheet_headline_topics,
      PaywallBenefitId.pushes => LocaleKeys.paywall_sheet_headline_pushes,
      PaywallBenefitId.history => LocaleKeys.paywall_sheet_headline_history,
      PaywallBenefitId.widgets => LocaleKeys.paywall_sheet_headline_widgets,
      PaywallBenefitId.appIcons => LocaleKeys.paywall_sheet_headline_app_icons,
      PaywallBenefitId.wakeUpChallenges =>
        LocaleKeys.paywall_sheet_headline_wake_up_challenges,
      PaywallBenefitId.reliabilityChecks =>
        LocaleKeys.paywall_sheet_headline_reliability_checks,
      PaywallBenefitId.customSounds =>
        LocaleKeys.paywall_sheet_headline_custom_sounds,
      PaywallBenefitId.customAlarmScreens =>
        LocaleKeys.paywall_sheet_headline_custom_alarm_screens,
      null => null,
    };
    return key?.tr();
  }

  /// "Make {name} critical" when the name is at most 16 characters and two
  /// lines hold it. Then "Make this topic critical". A longer name is
  /// never cut: the headline has no name.
  /// A headline that says what the card the person tapped says is passed
  /// over. The kit sets the headline at the compact size on every phone.
  String _topicsHeadline(BuildContext context, PaywallOffer offer) {
    final name = sheetHeadlineName(offer.lead?.topicName);
    final style = _headlineStyle(context);
    final width = _headlineWidth(context);
    final named = name == null
        ? null
        : LocaleKeys.paywall_own_count_headline_named.tr(
            namedArgs: {'name': name},
          );
    final fits = named != null && _fitsTwoLines(context, named, style, width);
    // The sentences on the lit row above the sheet.
    final tapped = [
      LocaleKeys.paywall_sheet_page_critical_used.tr(
        namedArgs: HostedBenefit.args,
      ),
      LocaleKeys.paywall_sheet_page_critical_lifted.tr(
        namedArgs: {'name': paywallProductName(offer.product)},
      ),
    ];
    final candidates = [
      if (sheetTopicHeadlineFor(name: name, fits: fits) ==
          SheetTopicHeadline.named)
        named!,
      LocaleKeys.paywall_own_count_headline_generic.tr(),
      LocaleKeys.paywall_sheet_headline_topics.tr(),
    ];
    return candidates.firstWhere(
      (text) => !sheetHeadlineRepeats(text, tapped),
      orElse: () => candidates.last,
    );
  }

  /// The headline as the kit sets it in this layout, for measuring.
  static TextStyle _headlineStyle(BuildContext context) =>
      AppTypography.headline(
        Theme.of(context).colorScheme.onSurface,
        fontSize: HeroSizes.of(isCompact: true).headline,
      );

  /// The width the kit gives the headline: the side insets, and where the
  /// close control would be over it, room for that.
  static double _headlineWidth(BuildContext context) => heroHeadlineWidth(
    width: MediaQuery.sizeOf(context).width - heroSideInset * 2,
    endRoom: _headlineEndRoom(context),
  );

  /// How far from the right edge the headline stops.
  static double _headlineEndRoom(BuildContext context) =>
      sheetHeadlineEndRoomFor(
        width: MediaQuery.sizeOf(context).width,
        textScale: MediaQuery.textScalerOf(context).scale(100) / 100,
      );

  /// How much taller [text] set in [style] is than one line, in [width], at
  /// the text size the person chose. Zero for a headline of one line.
  static double _extraLines(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) => math.max(
    0,
    paywallTextHeight(context, text, style, width) -
        paywallTextHeight(context, 'Ag', style, width),
  );

  /// True when [text] set in [style] takes at most two lines in [width], at
  /// the text size the person chose.
  static bool _fitsTwoLines(
    BuildContext context,
    String text,
    TextStyle style,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    )..layout(maxWidth: math.max(0, width));
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = PaywallFrame.isCompactOf(context);
    // The screen behind is drawn outside the frame, from the same offer
    // the frame hands its builder.
    final offer = PaywallOffer.of(context);
    // The offer lists the route's lead first. With no lead the first
    // benefit leads, as before.
    final benefits = offer.benefits;
    final lead = benefits.firstOrNull;
    final kind = sheetPageKindFor(lead?.id);
    // A lead and at least one other benefit: the others sit under a small
    // label. The lit row, the headline and the preview already say the
    // lead, so it gets no line of its own.
    final showsAlso = heroShowsAlsoIncluded(
      hasLead: offer.lead != null,
      benefitCount: benefits.length,
    );
    // The critical limit: the person's own count and the topic they were
    // making, when the route carries any of them. The picture then draws a
    // tag and puts their topic on the row that switches on.
    final route = offer.lead;
    final own =
        route != null &&
            route.benefit == PaywallBenefitId.topics &&
            (route.usedCount != null ||
                route.limitCount != null ||
                route.topicName != null)
        ? TopicsPreviewOwn(
            topicName: route.topicName,
            used: route.usedCount,
            limit: route.limitCount,
          )
        : null;
    final headline = _headline(context, lead, offer);
    // The topics headline may take two lines. The plan counts the second one
    // so the picture keeps its room.
    final headlineExtra =
        lead?.id == PaywallBenefitId.topics && headline != null
        ? _extraLines(
            context,
            headline,
            _headlineStyle(context),
            _headlineWidth(context),
          )
        : 0.0;
    // After an intro the preview and the words come up with the sheet.
    final followsIntro =
        !isStill &&
        (PaywallIntroPlay.maybeOf(context)?.intro ?? PaywallIntroId.none) !=
            PaywallIntroId.none;
    final loop = _loop = HeroLoop(
      [for (final b in benefits) b.previewId],
      prelude: SheetMotion.preludeFor(followsIntro: followsIntro),
    );
    final player = _player;

    // As the full-screen frame does: the links row may reach a little into
    // the home indicator's inset.
    final bottomInset = math.max(0, media.viewPadding.bottom - Spacing.s3);
    final plan = sheetPlanFor(
      screenWidth: media.size.width,
      screenHeight: media.size.height,
      topInset: media.viewPadding.top,
      bottomInset: bottomInset.toDouble(),
      isCompact: isCompact,
      buyBlockHeight: _frame.buyBlockHeight.value,
      benefitCount: benefits.length,
      textScale: media.textScaler.scale(100) / 100,
      hasAlso: showsAlso,
      showsLead: false,
      headlineExtra: headlineExtra,
    );
    final showsAir = media.textScaler.scale(100) / 100 <= 1.01;
    final travel =
        media.size.height -
        plan.sheetTop +
        math.max(_extraTravel, plan.faceAbove + Spacing.s2);
    double drop(double t) => (1 - SheetMotion.rise(t)) * travel;

    // The mascot on the sheet's edge. It goes where the sheet goes.
    final mascot = player == null
        ? null
        : Positioned(
            top: plan.sheetTop - plan.faceAbove,
            left: heroSideInset,
            width: plan.faceSize,
            height: plan.faceSize,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      player.clock,
                      player,
                      _clock,
                    ]),
                    builder: (context, _) {
                      final frame = player.frame;
                      return Transform.translate(
                        offset: Offset(0, drop(t)),
                        child: plan.isFaceStill
                            // A narrow phone: small, still and wholly above
                            // the sheet's edge. It has no room to move in.
                            ? HeroMascot(size: plan.faceSize)
                            : plan.standsInFront
                            // It rode up with the sheet, so it has no
                            // entrance of its own: only the hop as the
                            // sheet lands.
                            ? HeroMascot(
                                size: plan.faceSize,
                                face: frame.face,
                                fromFace: frame.fromFace,
                                faceBlend: frame.faceBlend,
                                blink: frame.blink,
                                hop: math.max(
                                  frame.hop,
                                  isStill ? 0 : SheetMotion.landingHop(t),
                                ),
                                bob: frame.bob,
                                props: frame.props,
                                idle: SheetMotion.stage.idle,
                                turnSeconds: frame.sceneSeconds,
                              )
                            : HeroMascot.frame(frame, size: plan.faceSize),
                      );
                    },
                  ),
                ),
              ),
            ),
          );

    // The row the user tapped. It answers when the lead's turn has done
    // its job on the stage.
    Widget litRow(double proof) => SheetLitRow(
      plan: plan,
      kind: kind,
      lead: lead,
      badge: paywallProductName(offer.product),
      proof: proof,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The screen behind is under a scrim in both themes.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.canvas,
        resizeToAvoidBottomInset: false,
        // A plan made before the buy block has a height is laid out and
        // not painted, so the first frame on screen has the row count the
        // settled one has.
        body: Opacity(
          opacity: plan.isMeasured ? 1 : 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: MediaQuery.withNoTextScaling(
                  child: SheetPage(plan: plan, kind: kind),
                ),
              ),
              IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _clock,
                  builder: (context, t, child) =>
                      Opacity(opacity: SheetMotion.scrim(t), child: child),
                  child: const AppScrim(),
                ),
              ),
              // A tap on the screen behind closes the sheet, as the cross
              // does. The cross is the control a screen reader gets.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: plan.sheetTop,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _frame.close,
                  ),
                ),
              ),
              Positioned(
                top: plan.litTop,
                left: Spacing.s4,
                right: Spacing.s4,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: MediaQuery.withNoTextScaling(
                      child: player == null
                          ? litRow(0)
                          : ListenableBuilder(
                              // A touch with nothing moving has no tick.
                              listenable: Listenable.merge([
                                player.clock,
                                player,
                              ]),
                              builder: (context, _) => litRow(
                                SheetMotion.proofFor(
                                  loop,
                                  player.frame,
                                  isStill: player.isStill,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              // Past the default text size the mascot stands behind the
              // sheet and looks over its edge at the lit row.
              if (mascot != null && !plan.standsInFront) mascot,
              Positioned(
                top: plan.sheetTop,
                left: 0,
                right: 0,
                bottom: -_underhang,
                child: ValueListenableBuilder<double>(
                  valueListenable: _clock,
                  builder: (context, t, child) => Transform.translate(
                    offset: Offset(0, drop(t)),
                    child: child,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(Radii.xl),
                      ),
                      boxShadow: AppShadows.shadowLg(isDark: isDark),
                    ),
                  ),
                ),
              ),
              // A seat for the close cross. The cross is on screen before the
              // sheet is, and this keeps it readable over the screen behind.
              Positioned(
                top:
                    plan.sheetTop +
                    (PaywallLayoutScope.closeCrossSize - 32) / 2,
                right:
                    PaywallLayoutScope.closeCrossInset +
                    (PaywallLayoutScope.closeCrossSize - 32) / 2,
                child: IgnorePointer(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.ash,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: plan.sheetTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset.toDouble()),
                  // The stage's air stops at the sheet's edge: there is no
                  // status bar above it to run under.
                  child: MediaQuery.removeViewPadding(
                    context: context,
                    removeTop: true,
                    child: PaywallFrameBody(
                      controller: _frame,
                      tone: PaywallTone.surface,
                      closeOnLeft: false,
                      // A sheet comes up: its own cue, in place of the
                      // one a full screen opens with.
                      entranceCue: PaywallEntranceCue.rise,
                      // It comes in as the sheet lands. With nothing moving
                      // it is there from the first frame.
                      buyBlockVisible: isStill || _buyIn,
                      restAt: restAt,
                      buyStyle: const PaywallBuyBlockStyle(
                        tone: PaywallTone.surface,
                      ),
                      builder: (context, scope) =>
                          ValueListenableBuilder<double>(
                            valueListenable: _clock,
                            builder: (context, t, child) => Transform.translate(
                              offset: Offset(0, drop(t)),
                              child: child,
                            ),
                            child: Stack(
                              children: [
                                // The drifting shapes, kept clear of the
                                // cross. A large text size leaves the stage
                                // no room, and then there is no air either.
                                if (showsAir)
                                  Positioned(
                                    top: _airTop,
                                    left: 0,
                                    right: _airRight,
                                    height: math.max(
                                      0,
                                      scope.size.height -
                                          sheetWordsHeight(
                                            benefits.length,
                                            hasAlso: showsAlso,
                                            showsLead: false,
                                            headlineExtra: headlineExtra,
                                          ) -
                                          _airTop -
                                          _airBottom,
                                    ),
                                    child: _SheetAir(player: _playerFor(scope)),
                                  ),
                                HeroComposition(
                                  // The lead first, and the words at the
                                  // kit's compact sizes on every phone: a
                                  // sheet has less room than a screen, and
                                  // the preview gets it.
                                  scope: PaywallLayoutScope(
                                    product: scope.product,
                                    benefits: benefits,
                                    size: scope.size,
                                    isCompact: true,
                                    source: scope.source,
                                    clock: scope.clock,
                                    closeOnLeft: scope.closeOnLeft,
                                    close: scope.close,
                                    lead: scope.lead,
                                  ),
                                  tone: PaywallTone.surface,
                                  headline: headline,
                                  // The same picture the stage draws, with
                                  // the person's own numbers in it.
                                  sceneBuilder: own == null
                                      ? null
                                      : (context, scene, size, playFrom) {
                                          final preview = scene.preview;
                                          if (preview == null) {
                                            return SizedBox.fromSize(
                                              size: size,
                                            );
                                          }
                                          return PaywallPreview(
                                            preview,
                                            sizeClass:
                                                PaywallPreviewClass.large,
                                            size: size,
                                            playFrom: playFrom,
                                            topicsOwn:
                                                preview ==
                                                    PaywallPreviewId.topics
                                                ? own
                                                : null,
                                          );
                                        },
                                  loop: loop,
                                  player: _playerFor(scope),
                                  arrange: (size) => sheetStageArrangement(
                                    size,
                                    face: plan.showsFaceBesideCard
                                        ? plan.faceSize
                                        : 0,
                                  ),
                                  showsShapes: false,
                                  motion: SheetMotion.stage,
                                  // The sheet has its own: the rise and
                                  // the landing.
                                  entranceCues: const [],
                                  alsoIncluded: showsAlso
                                      ? LocaleKeys.paywall_also_label.tr()
                                      : null,
                                  showsLeadLine: false,
                                  // The cross is over the headline when the
                                  // stage has no room above it.
                                  headlineEndRoom: _headlineEndRoom(context),
                                  // A list is never cut at its foot.
                                  showsWholeLinesOnly: true,
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              // At the default text size the mascot stands whole in front
              // of the sheet, astride its top edge, beside the preview.
              if (mascot != null && plan.standsInFront) mascot,
            ],
          ),
        ),
      ),
    );
  }
}

/// The kit's drifting shapes behind the stage, with no disc of their own:
/// the stage draws that. They follow the same entrance and the same clock.
class _SheetAir extends StatelessWidget {
  const _SheetAir({required this.player});

  final HeroPlayer player;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: PaywallClockBuilder(
          clock: player.clock,
          builder: (context, t, _) => LayoutBuilder(
            builder: (context, box) => HeroAtmosphere(
              focus: box.biggest.center(Offset.zero),
              radius: 0,
              seconds: player.stageSeconds(t),
              entrance: player.frameAt(t).entrance,
              tone: PaywallTone.surface,
              style: SheetMotion.stage.atmosphere,
            ),
          ),
        ),
      ),
    ),
  );
}

/// This layout's clock, for the parts drawn outside the frame.
class _SheetClock extends ChangeNotifier implements ValueListenable<double> {
  _SheetClock(this._read);

  final double Function() _read;

  @override
  double get value => _read();

  void tell() => notifyListeners();
}
