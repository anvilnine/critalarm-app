import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_reporter.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:critalarm/core/paywall/paywall_thanks.dart';
export 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_rules.dart';

// The step after a purchase: what plays once the product is known to be
// held, and the frame it rests on. The kit README has the contract. This
// file is what a version is built on and the host that plays one over a
// layout.

/// The room the host's one button takes at the foot of the screen, above
/// the bottom safe area. A version draws nothing there.
const double paywallThanksButtonRoom = 76;

/// How long the quiet version for a restore takes to come in, and when its
/// button is on.
const double paywallThanksQuietSeconds = 0.7;
const double paywallThanksQuietButtonAt = 0.3;

/// How long a frame that plays no show takes to come over the layout.
const double paywallThanksAppearSeconds = 0.25;

/// What a version draws with.
@immutable
class PaywallThanksScope {
  const PaywallThanksScope({
    required this.clock,
    required this.size,
    required this.padding,
    required this.product,
    required this.benefits,
    this.origin,
    this.mascot,
  });

  /// Seconds since the purchase was confirmed, which is the frame the
  /// purchase cue starts. From `PaywallThanks.seconds` on it is the resting
  /// frame, and the clock runs on so the mascot may blink and bob. When
  /// nothing may move it reads exactly that second and stays there.
  final PaywallClock clock;

  /// The whole screen, safe areas included. A version draws edge to edge.
  final Size size;

  /// The safe areas, to keep words out of.
  final EdgeInsets padding;

  final PaywallProduct product;

  /// What the buyer now has: the product's benefits this build really has,
  /// in display order. Never one that is not built.
  final List<PaywallBenefit> benefits;

  /// The buy button the buyer pressed, where the layout had it. The show
  /// grows out of it. Null when there was none to find, and when no show
  /// plays.
  final Rect? origin;

  /// The layout's own mascot as it was painted when the purchase was
  /// confirmed. A version starts its mascot there, so the two read as one.
  /// Null when the layout shows none.
  final Rect? mascot;

  /// Where a version may draw words: the screen less the safe areas and
  /// the host's button.
  Rect get room => Rect.fromLTRB(
    0,
    padding.top,
    size.width,
    size.height - padding.bottom - paywallThanksButtonRoom,
  );

  /// Where the show grows from: the middle of [origin], or of where a buy
  /// button usually is.
  Offset get source =>
      origin?.center ?? Offset(size.width / 2, room.bottom - Spacing.s6);
}

/// Draws a version for the second its scope's clock reads.
typedef PaywallThanksBuilder =
    Widget Function(BuildContext context, PaywallThanksScope scope);

/// The beats of a version that lists `lines` benefits.
typedef PaywallThanksBeats = List<PaywallThanksBeat> Function(int lines);

List<PaywallThanksBeat> _noBeats(int lines) => const [];

/// One version of the step after a purchase: how long its show is and
/// what draws it.
///
/// Second zero is the frame the purchase is confirmed. The buy block plays
/// the purchase cue on that frame, so a version never plays it and times
/// its show to it: see [paywallBoughtCueSeconds].
@immutable
class PaywallThanks {
  const PaywallThanks({
    required this.seconds,
    required this.cover,
    required this.buttonAt,
    required this.builder,
    this.tone = PaywallTone.canvas,
    this.beats = _noBeats,
  });

  /// The length of the show. From here on the version draws its resting
  /// frame, which is also what a tap skips to and what reduce motion shows.
  final double seconds;

  /// The second from which the version covers the whole screen. The host
  /// takes the layout away then, so until this the version draws the
  /// growing edge and after it every pixel.
  final double cover;

  /// The second the host's button comes on. At most
  /// [paywallThanksButtonBy].
  final double buttonAt;

  /// What the resting frame is painted on. It picks the button.
  final PaywallTone tone;

  /// What is felt on the way. See [PaywallThanksBeat].
  final PaywallThanksBeats beats;

  final PaywallThanksBuilder builder;

  /// Whether the times are in order, the button is on soon enough and no
  /// beat makes a sound under the purchase cue. A test asks this of every
  /// registered version.
  bool get isSound {
    for (var lines = 1; lines <= paywallThanksMaxLines; lines++) {
      if (!paywallThanksBeatsAreSound(beats(lines), seconds: seconds)) {
        return false;
      }
    }
    return cover > 0 &&
        cover <= buttonAt &&
        buttonAt <= paywallThanksButtonBy &&
        buttonAt < seconds &&
        seconds >= 1.5 &&
        seconds <= 6;
  }
}

/// The second a tap at [t] moves a show [seconds] long to: its resting
/// frame, and no change once it is there.
double paywallThanksSkip(double seconds, double t) => t < seconds ? seconds : t;

/// Plays what was chosen for after a purchase over [child], which is a
/// layout with its intro.
///
/// - With [PaywallThanksId.none], or an id this build has no version for,
///   it is not there at all: the purchase ends as it always has.
/// - It starts on the frame the buy model says the product is held after a
///   trip to the store, and never before. A cancel, a failure, a restore
///   that found nothing and a held payment start nothing.
/// - A confirmed purchase plays the show once. A restore that worked gets
///   a short quiet frame. A product that was already held gets the resting
///   frame with no show.
/// - A tap anywhere skips the show to its resting frame. The one button
///   calls [onDone].
/// - With reduce motion on, or under a `PaywallStill`, the resting frame
///   is there at once and nothing moves.
class PaywallThanksHost extends StatefulWidget {
  const PaywallThanksHost({
    required this.thanks,
    required this.product,
    required this.child,
    this.onDone,
    super.key,
  });

  final PaywallThanksId thanks;
  final PaywallProduct product;

  /// Where the one button goes. Null in a thumbnail, which has no touch.
  final VoidCallback? onDone;
  final Widget child;

  @override
  State<PaywallThanksHost> createState() => _PaywallThanksHostState();
}

class _PaywallThanksHostState extends State<PaywallThanksHost>
    with SingleTickerProviderStateMixin {
  final PaywallThanksHandle _handle = PaywallThanksHandle();
  final _ThanksClock _clock = _ThanksClock();
  final GlobalKey _layoutKey = GlobalKey();
  late final Ticker _ticker;
  late final PaywallBuyCubit _buy;
  late PaywallBuyState _before;

  /// The version set for this paywall, or null for none.
  PaywallThanks? _thanks;

  /// Why the step is on screen, or null while it is not.
  PaywallThanksKind? _kind;

  /// Seconds run before the ticker last started, and what a tap added.
  double _banked = 0;
  double _skipped = 0;

  /// The second up to which beats have played.
  double _heard = 0;

  /// The layout under the step is fully covered and has been taken away.
  bool _isCovered = false;
  bool _wasSkipped = false;
  bool _leftByButton = false;

  Rect? _origin;
  Rect? _mascot;
  PaywallLayoutReporter? _reporter;

  bool get _isStill =>
      (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
      PaywallStill.of(context);

  /// The length of what plays for [_kind], and when it covers the screen.
  double get _seconds => switch (_kind) {
    PaywallThanksKind.purchase => _thanks!.seconds,
    PaywallThanksKind.restore => paywallThanksQuietSeconds,
    PaywallThanksKind.owned || null => 0,
  };

  double get _coverAt => switch (_kind) {
    PaywallThanksKind.purchase => _thanks!.cover,
    _ => paywallThanksAppearSeconds,
  };

  /// The first second the clock reads for [kind]. A show starts at zero.
  /// The resting frame of a product already held starts where the show
  /// would have ended.
  double _startFor(PaywallThanksKind kind) =>
      kind == PaywallThanksKind.owned ? _thanks!.seconds : 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _buy = context.read<PaywallBuyCubit>();
    _before = _buy.state;
    _thanks = paywallThanksBuilders[widget.thanks];
  }

  void _onBuy(BuildContext context, PaywallBuyState after) {
    final before = _before;
    _before = after;
    if (_thanks == null || _kind != null) return;
    final kind = paywallThanksKindFor(before, after, action: _buy.lastAction);
    if (kind != null) setState(() => _start(kind));
  }

  /// Puts the step on screen. The layout is still laid out as the buyer
  /// saw it, so this is the moment to read where its button and its
  /// mascot are.
  void _start(PaywallThanksKind kind) {
    _kind = kind;
    _handle.hasBegun = true;
    if (kind == PaywallThanksKind.purchase) {
      _origin = _find((widget) => widget is AppButton, under: PaywallBuyBlock);
      _mascot = _findMascot();
    }
    final isStill = _isStill;
    final start = _startFor(kind);
    _banked = isStill ? _seconds + start : start;
    _skipped = 0;
    _clock.seconds = _banked;
    _heard = _banked;
    _isCovered = isStill;
    final reporter = _buy.reporter;
    if (reporter is PaywallLayoutReporter && !PaywallMuted.of(context)) {
      _reporter = reporter..thanksShown(kind.wire);
    }
    _sync();
  }

  /// Seconds since the step came on screen, whatever it started at.
  double get _run => _clock.seconds - (_kind == null ? 0 : _startFor(_kind!));

  void _onTick(Duration elapsed) {
    final thanks = _thanks;
    if (thanks == null || _kind == null) return;
    final t = _banked + elapsed.inMicroseconds / 1e6 + _skipped;
    _clock.seconds = t;
    if (_kind == PaywallThanksKind.purchase && !PaywallMuted.of(context)) {
      final cues = getIt<PaywallCues>();
      final beats = thanks.beats(paywallBenefitsFor(widget.product).length);
      // Single short beats under the purchase cue. Nothing here vibrates
      // as an alarm does.
      for (final beat in paywallThanksBeatsBetween(beats, _heard, t)) {
        beat.play(cues);
      }
    }
    _heard = t;
    if (!_isCovered && _run >= _coverAt) setState(() => _isCovered = true);
    _clock.tell();
  }

  void _skip() {
    if (_kind != PaywallThanksKind.purchase) return;
    final now = _clock.seconds;
    final to = paywallThanksSkip(_seconds, now);
    if (to == now) return;
    _skipped += to - now;
    _clock.seconds = to;
    // The moments a tap jumps over are not played.
    _heard = to;
    _wasSkipped = true;
    if (!PaywallMuted.of(context)) AppHaptics.play(HapticPattern.tick);
    if (_isCovered) return _clock.tell();
    setState(() => _isCovered = true);
  }

  void _goOn() {
    final kind = _kind;
    if (kind == null || _leftByButton) return;
    _leftByButton = true;
    _reporter?.thanksLeft(kind.wire, how: 'button', skipped: _wasSkipped);
    widget.onDone?.call();
  }

  /// The first widget [test] accepts under the first [under] in the
  /// layout, as it is painted now, in this host's coordinates.
  Rect? _find(bool Function(Widget widget) test, {required Type under}) {
    Element? found;
    void visit(Element element, {required bool isInside}) {
      if (found != null) return;
      final inside = isInside || element.widget.runtimeType == under;
      if (inside && test(element.widget)) {
        found = element;
        return;
      }
      element.visitChildren((child) => visit(child, isInside: inside));
    }

    _layoutKey.currentContext?.visitChildElements(
      (child) => visit(child, isInside: false),
    );
    return _paintedRect(found);
  }

  /// The largest face in the layout that counts as its mascot, as it is
  /// painted now. A face that is mostly out, mid entrance, counts as none.
  Rect? _findMascot() {
    Element? found;
    var edge = 64.0;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is FaceWidget && widget.size >= edge) {
        found = element;
        edge = widget.size;
      }
      element.visitChildren(visit);
    }

    _layoutKey.currentContext?.visitChildElements(visit);
    final rect = _paintedRect(found);
    return rect == null || rect.width < edge * 0.7 ? null : rect;
  }

  Rect? _paintedRect(Element? element) {
    final box = element?.findRenderObject();
    final host = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    if (host is! RenderBox) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(host),
      Offset.zero & box.size,
    );
  }

  /// Starts or stops the ticker for what is true now.
  void _sync() {
    final isOnTop = ModalRoute.of(context)?.isCurrent ?? true;
    final isStill = _isStill;
    _clock.still = isStill;
    final shouldRun = _kind != null && !isStill && isOnTop;
    if (!shouldRun && _ticker.isActive) {
      _banked = _clock.seconds - _skipped;
      _ticker.stop();
    } else if (shouldRun && !_ticker.isActive) {
      unawaited(_ticker.start());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final kind = _kind;
    if (_thanks != null && kind == null) {
      // The product was held before this paywall opened.
      if (_before.status == PaywallBuyStatus.done) {
        _start(PaywallThanksKind.owned);
      }
    } else if (kind != null && _isStill) {
      // Motion was turned off half way: the resting frame, at once.
      final rest = _startFor(kind) + _seconds;
      if (_clock.seconds < rest) {
        _skipped += rest - _clock.seconds;
        _clock.seconds = rest;
        _heard = rest;
      }
      _isCovered = true;
    }
    _sync();
  }

  @override
  void dispose() {
    final kind = _kind;
    if (kind != null && !_leftByButton) {
      _reporter?.thanksLeft(kind.wire, how: 'away', skipped: _wasSkipped);
    }
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thanks = _thanks;
    if (thanks == null) return widget.child;
    final kind = _kind;
    final isAway = _isCovered;

    return PaywallThanksPlay(
      handle: _handle,
      child: BlocListener<PaywallBuyCubit, PaywallBuyState>(
        listener: _onBuy,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Once covered the layout is neither painted nor ticking. It
            // stays built, so nothing of it is torn down mid show.
            Offstage(
              offstage: isAway,
              child: PaywallStill(
                isStill: isAway || PaywallStill.of(context),
                child: KeyedSubtree(key: _layoutKey, child: widget.child),
              ),
            ),
            if (kind != null)
              Positioned.fill(
                child: _ThanksLayer(
                  thanks: thanks,
                  kind: kind,
                  clock: _clock,
                  start: _startFor(kind),
                  product: widget.product,
                  origin: _origin,
                  mascot: _mascot,
                  onSkip: _skip,
                  onGoOn: _goOn,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The step itself, edge to edge, with the one button at its foot.
class _ThanksLayer extends StatelessWidget {
  const _ThanksLayer({
    required this.thanks,
    required this.kind,
    required this.clock,
    required this.start,
    required this.product,
    required this.origin,
    required this.mascot,
    required this.onSkip,
    required this.onGoOn,
  });

  final PaywallThanks thanks;
  final PaywallThanksKind kind;
  final PaywallClock clock;

  /// The second the clock read when the step came on.
  final double start;
  final PaywallProduct product;
  final Rect? origin;
  final Rect? mascot;
  final VoidCallback onSkip;
  final VoidCallback onGoOn;

  /// The text size the step stops growing at. It is one screen.
  static const double _maxTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final isShow = kind == PaywallThanksKind.purchase;
    final isQuiet = kind == PaywallThanksKind.restore;
    final buttonAt = isShow
        ? thanks.buttonAt
        : isQuiet
        ? paywallThanksQuietButtonAt
        : 0.0;

    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final scope = PaywallThanksScope(
          clock: clock,
          size: constraints.biggest,
          padding: padding,
          product: product,
          benefits: paywallBenefitsFor(product),
          origin: origin,
          mascot: mascot,
        );
        return isQuiet
            ? ThanksQuiet(scope: scope, tone: thanks.tone)
            : thanks.builder(context, scope);
      },
    );
    // A frame with no show of its own comes over the layout in one short
    // fade. A show draws its own way in.
    if (!isShow) {
      content = PaywallClockBuilder(
        clock: clock,
        builder: (context, t, child) {
          final appear = clock.isStill
              ? 1.0
              : phase(t - start, 0, paywallThanksAppearSeconds);
          return appear >= 1 ? child! : Opacity(opacity: appear, child: child);
        },
        child: content,
      );
    }

    // The layout's own scaffold is not above this layer.
    return Material(
      type: MaterialType.transparency,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: _maxTextScale,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A tap anywhere is a tap on the show: it goes to its resting
            // frame. Nothing under this layer takes a touch again.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: onSkip,
              child: RepaintBoundary(child: content),
            ),
            Positioned(
              left: thanksSideInset,
              right: thanksSideInset,
              bottom: padding.bottom + Spacing.s4,
              child: PaywallClockBuilder(
                clock: clock,
                builder: (context, t, child) {
                  final on = clock.isStill
                      ? 1.0
                      : phase(t - start, buttonAt, buttonAt + 0.28);
                  final eased = AppCurves.easeOut.transform(on);
                  return IgnorePointer(
                    ignoring: on < 0.2,
                    child: ExcludeSemantics(
                      excluding: on < 0.2,
                      child: Opacity(
                        opacity: on,
                        child: Transform.translate(
                          offset: Offset(0, (1 - eased) * Spacing.s4),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: AppButton(
                  label: LocaleKeys.paywall_thanks_button.tr(),
                  variant: paywallButtonVariantFor(thanks.tone),
                  isFullWidth: true,
                  onPressed: onGoOn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The step's own clock: seconds since the purchase was confirmed, moved
/// on by a tap.
class _ThanksClock extends ChangeNotifier implements PaywallClock {
  double seconds = 0;
  bool still = false;

  @override
  double get value => seconds;

  @override
  bool get isStill => still;

  @override
  void restart() {}

  void tell() => notifyListeners();
}
