import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

export 'package:critalarm/core/paywall/paywall_intro.dart';

// An intro: a short full screen animation that plays once when a paywall
// opens and hands over to whichever layout was chosen. The kit README has
// the contract. This file is everything an intro is built on and the host
// that plays one over a layout.

/// What an intro draws with.
@immutable
class PaywallIntroScope {
  const PaywallIntroScope({
    required this.clock,
    required this.size,
    required this.padding,
    required this.product,
  });

  /// Seconds since the intro began. A tap moves it on to
  /// [PaywallIntro.skipTo]. Draw every part from it with
  /// `PaywallClockBuilder`.
  final PaywallClock clock;

  /// The whole screen, safe areas included. An intro draws edge to edge.
  final Size size;

  /// The safe areas, to keep words out of.
  final EdgeInsets padding;

  /// What the layout under it sells.
  final PaywallProduct product;
}

/// Draws an intro for the second its scope's clock reads.
typedef PaywallIntroBuilder =
    Widget Function(BuildContext context, PaywallIntroScope scope);

/// One intro: how long it is, when it hands over, and what draws it.
///
/// The layout under it is built from the first frame with its clock held
/// at zero. At [handover] that clock starts, so the layout's own entrance
/// plays while the intro leaves. So an intro ends on the mascot and, from
/// [handover] to [seconds], uncovers the layout: it draws nothing where
/// the layout should show. At [seconds] it is taken away.
@immutable
class PaywallIntro {
  const PaywallIntro({
    required this.seconds,
    required this.handover,
    required this.builder,
    double? skipTo,
    this.tone = PaywallTone.canvas,
    this.cue = PaywallEntranceCue.open,
  }) : skipTo = skipTo ?? handover;

  /// The whole length. About 1.5 to 2.5 seconds.
  final double seconds;

  /// The second the layout's clock starts. Until then the intro covers the
  /// whole screen and a tap anywhere skips it.
  final double handover;

  /// The second a tap moves the clock on to: the start of the intro's way
  /// out. At most [handover], which is the default.
  final double skipTo;

  /// What the intro paints the screen in while it covers it. It colours
  /// the close cross, which is on screen from the first frame.
  final PaywallTone tone;

  /// The cue played once as the intro starts, in place of the layout's.
  final PaywallEntranceCue cue;

  final PaywallIntroBuilder builder;

  /// Whether the times are in order and the length is one an intro may
  /// have. A test asks this of every registered intro.
  bool get isSound =>
      skipTo > 0 &&
      skipTo <= handover &&
      handover < seconds &&
      seconds >= 1 &&
      seconds <= 3;
}

/// The second a tap at [t] moves an intro's clock to: [PaywallIntro.skipTo]
/// while it has not got there, and no change after.
double paywallIntroSkip(PaywallIntro intro, double t) =>
    t < intro.skipTo ? intro.skipTo : t;

/// Plays [cue] on [cues].
void playPaywallEntranceCue(PaywallCues cues, PaywallEntranceCue cue) {
  switch (cue) {
    case PaywallEntranceCue.open:
      cues.open();
    case PaywallEntranceCue.gag:
      cues.gag();
    case PaywallEntranceCue.print:
      cues.print();
    case PaywallEntranceCue.none:
      break;
  }
}

/// What the layout's frame tells the intro playing over it.
class PaywallIntroHandle {
  /// Which top corner the layout's close cross is in. The intro's own
  /// cross sits in the same one.
  bool closeOnLeft = false;
}

/// Says which intro plays over the layout below. [PaywallIntroHost] puts
/// it there and the frame reads it into `PaywallLayoutScope.intro`.
class PaywallIntroPlay extends InheritedWidget {
  const PaywallIntroPlay({
    required this.intro,
    required this.handle,
    required super.child,
    super.key,
  });

  /// `none` when no intro plays on this open.
  final PaywallIntroId intro;
  final PaywallIntroHandle handle;

  static PaywallIntroPlay? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaywallIntroPlay>();

  /// The same without listening. Safe in `initState`.
  static PaywallIntroPlay? peek(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PaywallIntroPlay>();

  @override
  bool updateShouldNotify(PaywallIntroPlay oldWidget) =>
      intro != oldWidget.intro;
}

/// Plays [intro] once over [child], which is a layout, then gets out of
/// the way.
///
/// - The close cross is on screen from the first frame and closes the
///   paywall.
/// - A tap anywhere else moves the intro on to its way out.
/// - With reduce motion on, or under a `PaywallStill`, no intro plays at
///   all and the layout opens as it does alone.
/// - It plays once for as long as this widget lives. A rebuild does not
///   start it again.
class PaywallIntroHost extends StatefulWidget {
  const PaywallIntroHost({
    required this.intro,
    required this.product,
    required this.child,
    super.key,
  });

  final PaywallIntroId intro;
  final PaywallProduct product;
  final Widget child;

  @override
  State<PaywallIntroHost> createState() => _PaywallIntroHostState();
}

class _PaywallIntroHostState extends State<PaywallIntroHost>
    with SingleTickerProviderStateMixin {
  final PaywallIntroHandle _handle = PaywallIntroHandle();
  final _IntroClock _clock = _IntroClock();
  late final Ticker _ticker;

  /// The intro being played, or null when none is: no intro was asked
  /// for, this build has none for the id, or nothing may move.
  PaywallIntro? _intro;
  bool _hasDecided = false;

  /// Seconds run before the ticker last started, and what taps added.
  double _banked = 0;
  double _skipped = 0;

  bool _hasHandedOver = false;
  bool _isOver = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    _clock.seconds = _banked + elapsed.inMicroseconds / 1e6 + _skipped;
    _advance();
  }

  /// Tells the layout to start, and takes the intro away, as the clock
  /// passes each.
  void _advance() {
    final intro = _intro;
    if (intro == null) return;
    final t = _clock.seconds;
    final handsOver = !_hasHandedOver && t >= intro.handover;
    final ends = !_isOver && t >= intro.seconds;
    if (handsOver && !PaywallMuted.of(context)) {
      // One light tap as the layout takes over. Nothing here vibrates as
      // an alarm does.
      AppHaptics.selection();
    }
    if (ends) _ticker.stop();
    _clock.tell();
    if (!handsOver && !ends) return;
    setState(() {
      _hasHandedOver = _hasHandedOver || handsOver;
      _isOver = _isOver || ends;
    });
  }

  void _skip() {
    final intro = _intro;
    if (intro == null || _isOver) return;
    final now = _clock.seconds;
    final to = paywallIntroSkip(intro, now);
    if (to == now) return;
    _skipped += to - now;
    _clock.seconds = to;
    _advance();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isStill =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        PaywallStill.of(context);
    if (!_hasDecided) {
      _hasDecided = true;
      _intro = isStill ? null : paywallIntroBuilders[widget.intro];
      final intro = _intro;
      if (intro != null && !PaywallMuted.of(context)) {
        playPaywallEntranceCue(getIt<PaywallCues>(), intro.cue);
      }
    } else if (isStill && _intro != null && !_isOver) {
      // Motion was turned off half way: the intro goes at once.
      _hasHandedOver = true;
      _isOver = true;
    }
    final isOnTop = ModalRoute.of(context)?.isCurrent ?? true;
    final shouldRun = _intro != null && !_isOver && isOnTop;
    if (!shouldRun && _ticker.isActive) {
      _banked = _clock.seconds - _skipped;
      _ticker.stop();
    } else if (shouldRun && !_ticker.isActive) {
      unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intro = _intro;
    final isPlaying = intro != null && !_isOver;

    return PaywallIntroPlay(
      intro: intro == null ? PaywallIntroId.none : widget.intro,
      handle: _handle,
      child: PaywallClockHold(
        isHeld: intro != null && !_hasHandedOver,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (isPlaying)
              Positioned.fill(
                child: _IntroLayer(
                  intro: intro,
                  clock: _clock,
                  product: widget.product,
                  handle: _handle,
                  takesTaps: !_hasHandedOver,
                  onSkip: _skip,
                  onClose: _close,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The intro itself, edge to edge, under its close cross.
class _IntroLayer extends StatelessWidget {
  const _IntroLayer({
    required this.intro,
    required this.clock,
    required this.product,
    required this.handle,
    required this.takesTaps,
    required this.onSkip,
    required this.onClose,
  });

  final PaywallIntro intro;
  final PaywallClock clock;
  final PaywallProduct product;
  final PaywallIntroHandle handle;
  final bool takesTaps;
  final VoidCallback onSkip;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final ink = PaywallToneColors.of(context, intro.tone).ink;

    // The cross is an ink well, and the layout's own scaffold is not above
    // this layer.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Until the hand over a tap anywhere is a tap on the intro. After
          // it the layout under it takes the touch.
          IgnorePointer(
            ignoring: !takesTaps,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: onSkip,
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: LayoutBuilder(
                    builder: (context, constraints) => intro.builder(
                      context,
                      PaywallIntroScope(
                        clock: clock,
                        size: constraints.biggest,
                        padding: padding,
                        product: product,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The way out, in the corner the layout keeps its own cross. By
          // the hand over that corner is uncovered and the layout's own
          // cross, in its own colour, takes over without a move.
          if (takesTaps)
            SafeArea(
              bottom: false,
              child: Align(
                alignment: handle.closeOnLeft
                    ? Alignment.topLeft
                    : Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PaywallLayoutScope.closeCrossInset,
                  ),
                  child: AppDismissCross(
                    label: LocaleKeys.paywall_kit_close.tr(),
                    color: ink,
                    onPressed: onClose,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The intro's own clock: seconds since it began, moved on by a tap.
class _IntroClock extends ChangeNotifier implements PaywallClock {
  double seconds = 0;

  @override
  double get value => seconds;

  @override
  bool get isStill => false;

  @override
  void restart() {}

  void tell() => notifyListeners();
}
