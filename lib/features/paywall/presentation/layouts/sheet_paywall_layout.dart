import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_content.dart';
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
/// limit. The row they tapped stays lit above the scrim and the sheet
/// answers that one limit first.
///
/// The screen behind is a picture, drawn from what opened the paywall. The
/// sheet holds a `PaywallFrameBody`, which stays in its seat from the first
/// frame so the close cross is always there. The white surface, the words
/// and the face ride up over it.
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

  late final _SheetClock _clock = _SheetClock(() => t);
  final PaywallFrameController _frame = PaywallFrameController();

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
    _clock.dispose();
    super.dispose();
  }

  String _headline(PaywallOffer offer, PaywallBenefit? lead) {
    final name = paywallProductName(offer.product);
    final key = switch (lead?.id) {
      PaywallBenefitId.topics => LocaleKeys.paywall_sheet_headline_topics,
      PaywallBenefitId.pushes => LocaleKeys.paywall_sheet_headline_pushes,
      PaywallBenefitId.history => LocaleKeys.paywall_sheet_headline_history,
      PaywallBenefitId.widgets => LocaleKeys.paywall_sheet_headline_widgets,
      PaywallBenefitId.appIcons => LocaleKeys.paywall_sheet_headline_app_icons,
      PaywallBenefitId.weeklyCheck =>
        LocaleKeys.paywall_sheet_headline_weekly_check,
      PaywallBenefitId.fireDrills =>
        LocaleKeys.paywall_sheet_headline_fire_drills,
      PaywallBenefitId.wakeUpChallenges =>
        LocaleKeys.paywall_sheet_headline_wake_up_challenges,
      PaywallBenefitId.customAlarmScreens =>
        LocaleKeys.paywall_sheet_headline_custom_alarm_screens,
      PaywallBenefitId.morningSummary =>
        LocaleKeys.paywall_sheet_headline_morning_summary,
      null => null,
    };
    return key == null ? name : key.tr(namedArgs: {'name': name});
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
    final benefits = offer.benefits;
    final lead = sheetLeadBenefit(offer.source, benefits);
    final others = sheetOtherBenefits(lead, benefits);
    final kind = sheetPageKindFor(lead?.id);
    final isSwitch = kind == SheetPageKind.newTopic;

    // As the full-screen frame does: the links row may reach a little into
    // the home indicator's inset.
    final bottomInset = math.max(0, media.viewPadding.bottom - Spacing.s3);
    final plan = sheetPlanFor(
      screenHeight: media.size.height,
      topInset: media.viewPadding.top,
      bottomInset: bottomInset.toDouble(),
      isCompact: isCompact,
      buyBlockHeight: _frame.buyBlockHeight.value,
      isSwitch: isSwitch,
      benefitCount: benefits.length,
      textScale: media.textScaler.scale(100) / 100,
    );
    final travel = media.size.height - plan.sheetTop + _extraTravel;
    double drop(double t) => (1 - SheetMotion.rise(t)) * travel;

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
                child: ExcludeSemantics(
                  child: MediaQuery.withNoTextScaling(
                    child: SheetLitRow(
                      plan: plan,
                      kind: kind,
                      lead: lead,
                      badge: paywallProductName(offer.product),
                      clock: _clock,
                    ),
                  ),
                ),
              ),
              // The face looks over the sheet's edge at the lit row. It is
              // behind the sheet, so only its top half shows.
              Positioned(
                top: plan.sheetTop - plan.faceSize / 2,
                left: isSwitch ? (media.size.width - plan.faceSize) / 2 : null,
                right: isSwitch ? null : Spacing.s8,
                child: ExcludeSemantics(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _clock,
                    builder: (context, t, _) {
                      final peek = SheetMotion.peek(t);
                      return Transform.translate(
                        offset: Offset(
                          0,
                          drop(t) + (1 - peek) * SheetMotion.peekDrop,
                        ),
                        // Tilted only on the way in. Upright at rest.
                        child: Transform.rotate(
                          angle: (1 - peek) * SheetMotion.peekTilt,
                          child: FaceWidget(
                            state: isSwitch && SheetMotion.limitLifted(t)
                                ? FaceState.happy
                                : FaceState.curious,
                            size: plan.faceSize,
                          ),
                        ),
                      );
                    },
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
                  child: PaywallFrameBody(
                    controller: _frame,
                    tone: PaywallTone.surface,
                    closeOnLeft: false,
                    // It comes in as the sheet lands. With nothing moving it
                    // is there from the first frame.
                    buyBlockVisible: isStill || _buyIn,
                    restAt: restAt,
                    buyStyle: const PaywallBuyBlockStyle(
                      tone: PaywallTone.surface,
                    ),
                    builder: (context, scope) => ValueListenableBuilder<double>(
                      valueListenable: _clock,
                      builder: (context, t, child) => Transform.translate(
                        offset: Offset(0, drop(t)),
                        child: child,
                      ),
                      child: SheetContent(
                        headline: _headline(offer, lead),
                        lead: lead,
                        others: others,
                        isCompact: scope.isCompact,
                        clock: _clock,
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

/// This layout's clock, for the parts drawn outside the frame.
class _SheetClock extends ChangeNotifier implements ValueListenable<double> {
  _SheetClock(this._read);

  final double Function() _read;

  @override
  double get value => _read();

  void tell() => notifyListeners();
}
