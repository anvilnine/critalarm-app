import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/false_alarm/false_alarm_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/false_alarm/false_alarm_gag.dart';
import 'package:critalarm/features/paywall/presentation/layouts/false_alarm/false_alarm_tag.dart';
import 'package:critalarm/features/paywall/presentation/layouts/false_alarm/false_alarm_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Opens looking like an alarm going off, admits it is joking, and becomes
/// the offer.
///
/// For about a second and a half the whole screen is the alarm red, with
/// the mascot large and ringing over one big word. It is a silent picture:
/// the app makes no alarm. Then the mascot blinks, says so, and the stage
/// tone takes the screen back. From there it is the Hero composition, with
/// what the mascot said kept as a small tag beside it, so the joke still
/// reads on the resting frame.
///
/// The joke plays once. A tap during it skips to the reveal. The close
/// cross is there from the first frame and the buy block is not: it comes
/// in with the reveal. When nothing may move there is no red at all.
class FalseAlarmPaywallLayout extends StatefulWidget {
  const FalseAlarmPaywallLayout({super.key});

  @override
  State<FalseAlarmPaywallLayout> createState() =>
      _FalseAlarmPaywallLayoutState();
}

class _FalseAlarmPaywallLayoutState extends State<FalseAlarmPaywallLayout> {
  final FalseAlarmClock _clock = FalseAlarmClock(
    restAt: FalseAlarmTimeline.restAt,
  );

  /// Where the tag may stand, as the stage last arranged itself.
  final ValueNotifier<Rect?> _tagRoom = ValueNotifier<Rect?>(null);
  Rect? _askedTagRoom;

  bool _buyIn = false;
  bool _saidReveal = false;

  @override
  void initState() {
    super.initState();
    _clock.addListener(_onClock);
  }

  @override
  void dispose() {
    _clock
      ..removeListener(_onClock)
      ..dispose();
    _tagRoom.dispose();
    super.dispose();
  }

  void _onClock() {
    if (_clock.isStill) return;
    final t = _clock.value;
    if (!_saidReveal && t >= FalseAlarmTimeline.reveal) {
      _saidReveal = true;
      // One light tap as the joke turns. Nothing here vibrates as an
      // alarm does.
      AppHaptics.selection();
    }
    if (!_buyIn && FalseAlarmTimeline.showsBuyBlock(t)) {
      _buyIn = true;
      _afterBuild(() => setState(() {}));
    }
  }

  /// Runs [change] now, or after the frame when one is being built.
  void _afterBuild(VoidCallback change) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks) return change();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) change();
    });
  }

  /// The approved arrangement. It also notes where the tag has room.
  HeroArrangement _arrange(Size stage) {
    final arrangement = heroArrangementFor(stage);
    final room = falseAlarmTagRoom(stage: stage, arrangement: arrangement);
    if (room != _askedTagRoom) {
      _askedTagRoom = room;
      // The stage is being built: the tag is told after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tagRoom.value = room;
      });
    }
    return arrangement;
  }

  @override
  Widget build(BuildContext context) {
    final isStill = context.reduceMotion || PaywallStill.of(context);
    _clock.still = isStill;
    final tag = LocaleKeys.paywall_false_alarm_tag.tr();

    return PaywallFrame(
      // The mascot stands in the top left, so the cross takes the right.
      closeOnLeft: false,
      entranceCue: PaywallEntranceCue.gag,
      restAt: FalseAlarmTimeline.restAt,
      buyBlockVisible: isStill || _buyIn,
      backdrop: FalseAlarmGag(
        clock: _clock,
        word: LocaleKeys.paywall_false_alarm_word.tr(),
        admission: LocaleKeys.paywall_false_alarm_admission.tr(),
        onSkip: _clock.skip,
      ),
      builder: (context, frameScope) {
        _clock.follow(frameScope.clock);
        // The same scope on the clock a tap can move on, for the stage,
        // the words and every preview under them.
        final scope = PaywallLayoutScope(
          product: frameScope.product,
          benefits: frameScope.benefits,
          size: frameScope.size,
          isCompact: frameScope.isCompact,
          source: frameScope.source,
          clock: _clock,
          closeOnLeft: frameScope.closeOnLeft,
          close: frameScope.close,
        );

        return PaywallLayoutScopeProvider(
          scope: scope,
          child: Stack(
            children: [
              Positioned.fill(
                child: HeroComposition(
                  scope: scope,
                  loop: HeroLoop([
                    for (final benefit in scope.benefits) benefit.previewId,
                  ], prelude: FalseAlarmTimeline.prelude),
                  arrange: _arrange,
                ),
              ),
              ValueListenableBuilder<Rect?>(
                valueListenable: _tagRoom,
                builder: (context, room, _) {
                  if (room == null) return const SizedBox.shrink();
                  return Positioned.fromRect(
                    rect: room,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: PaywallClockBuilder(
                          clock: _clock,
                          builder: (context, t, _) => FalseAlarmTag(
                            text: tag,
                            isCompact: scope.isCompact,
                            entrance: phase(
                              t - FalseAlarmTimeline.prelude,
                              0.5,
                              0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // While the joke plays, a tap anywhere is a tap on the joke.
              PaywallClockBuilder(
                clock: _clock,
                builder: (context, t, _) => t >= FalseAlarmTimeline.reveal
                    ? const SizedBox.shrink()
                    : Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          excludeFromSemantics: true,
                          onTap: _clock.skip,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
