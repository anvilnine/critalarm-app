import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_lead_benefit.dart';
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
/// taps are the kit's. Two things are this layout's own. The mascot stands
/// behind the sheet, so only its eyes show over the edge. And when the
/// lead benefit has done its job on the stage, the lit row above answers:
/// the switch goes on, or the lock on its badge becomes a check.
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

  /// How far below its own height the sheet starts.
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

  @override
  double get restAt => SheetMotion.restAt;

  // Only what listens to the clock redraws on a tick.
  @override
  void onTick() {
    _clock.tell();
    if (!_buyIn && t >= SheetMotion.buyBlockAt) {
      setState(() => _buyIn = true);
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

  String? _headline(PaywallBenefit? lead) {
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = PaywallFrame.isCompactOf(context);
    // The screen behind is drawn outside the frame, from the same offer
    // the frame hands its builder.
    final offer = PaywallOffer.of(context);
    // The benefit the user was reaching for leads: first line, first turn.
    final benefits = sheetBenefitsLeadFirst(offer.source, offer.benefits);
    final lead = benefits.firstOrNull;
    final kind = sheetPageKindFor(lead?.id);
    final loop = HeroLoop([
      for (final b in benefits) b.previewId,
    ], prelude: SheetMotion.prelude);
    final player = _player;

    // As the full-screen frame does: the links row may reach a little into
    // the home indicator's inset.
    final bottomInset = math.max(0, media.viewPadding.bottom - Spacing.s3);
    final plan = sheetPlanFor(
      screenHeight: media.size.height,
      topInset: media.viewPadding.top,
      bottomInset: bottomInset.toDouble(),
      isCompact: isCompact,
      buyBlockHeight: _frame.buyBlockHeight.value,
      benefitCount: benefits.length,
      textScale: media.textScaler.scale(100) / 100,
    );
    final showsAir = media.textScaler.scale(100) / 100 <= 1.01;
    final travel = media.size.height - plan.sheetTop + _extraTravel;
    double drop(double t) => (1 - SheetMotion.rise(t)) * travel;

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
              // The mascot stands behind the sheet and looks over its edge
              // at the lit row. It is the stage's own mascot, playing the
              // same frame: only the sheet in front hides the rest of it.
              if (player != null)
                Positioned(
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
                          builder: (context, _) => Transform.translate(
                            offset: Offset(0, drop(t)),
                            child: HeroMascot.frame(
                              player.frame,
                              size: plan.faceSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
                                          sheetWordsHeight(benefits.length) -
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
                                  ),
                                  tone: PaywallTone.surface,
                                  headline: _headline(lead),
                                  loop: loop,
                                  player: _playerFor(scope),
                                  arrange: sheetStageArrangement,
                                  showsShapes: false,
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
              ),
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
