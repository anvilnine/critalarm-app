import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxParentData;
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
    this.handle,
  });

  /// What the host knows about the layout under the intro.
  final PaywallIntroHandle? handle;

  /// Where the layout's own mascot stands once its entrance is done, in
  /// the intro's coordinates. Null while it is not known, and when the
  /// layout has none. Read it every frame: the host finds it a little
  /// after the first one.
  ///
  /// An intro's mascot goes there on its way out and is gone by the hand
  /// over ([paywallIntroLeaveBox]), so the layout's mascot comes up where
  /// the intro's went down and the two read as one.
  Rect? get landing => handle?.landing;

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
    this.score,
    this.beats = const [],
    this.skipCue,
    this.quietAfter = paywallQuietAfterIntro,
    this.tag,
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
  /// Not played when the intro has a [score].
  final PaywallEntranceCue cue;

  /// The intro's own music, started on its first frame and timed to it,
  /// or null for none. It has the player for the whole intro, so the
  /// [beats] of an intro with a score are haptics alone, and [skipCue] is
  /// its last part alone. See [paywallIntroArrivalSeconds].
  final PaywallCue? score;

  /// What is heard and felt on the way, in order. See [PaywallIntroBeat].
  final List<PaywallIntroBeat> beats;

  /// Played when a tap skips the intro, in place of the beat at the second
  /// the tap lands on. Null plays that beat as the clock would have.
  final PaywallCue? skipCue;

  /// How long after the hand over the layout keeps its own entrance quiet,
  /// in seconds: the intro's last sound still has the room. An intro whose
  /// opening cue is long says how much of it is left by then.
  final double quietAfter;

  /// The few words the mascot is left saying once the intro is gone, or
  /// null for none. The host draws them as a small tag over the layout's
  /// own mascot for [paywallIntroTagSeconds] from the hand over, so the
  /// joke still reads on the layout.
  final String Function()? tag;

  final PaywallIntroBuilder builder;

  /// Whether the times are in order and the length is one an intro may
  /// have. A test asks this of every registered intro.
  bool get isSound {
    var last = 0.0;
    for (final beat in beats) {
      if (beat.at < last || beat.at > seconds) return false;
      last = beat.at;
    }
    return skipTo > 0 &&
        skipTo <= handover &&
        handover < seconds &&
        seconds >= 1 &&
        seconds <= 3;
  }
}

/// One moment of an intro that is heard or felt: the second it happens and
/// what plays then.
///
/// A beat is one cue of the palette, which carries its own haptic, or with
/// [PaywallIntroBeat.tap] a haptic alone, for a moment inside a sound that
/// is still playing. The host plays it as the clock passes [at], never
/// under a `PaywallMuted`, and never for a moment a tap skipped. Nothing
/// here may sound or feel like an alarm: single short cues, no run of
/// them, no ring.
@immutable
class PaywallIntroBeat {
  const PaywallIntroBeat(this.at, PaywallCue this.cue)
    : haptic = HapticPattern.none;

  /// A haptic with no sound of its own.
  const PaywallIntroBeat.tap(this.at, this.haptic) : cue = null;

  final double at;

  /// The cue played, or null for a haptic alone.
  final PaywallCue? cue;

  /// The haptic played alone when there is no [cue].
  final HapticPattern haptic;

  /// Plays the beat: its cue on [cues], or its haptic alone.
  void play(PaywallCues cues) {
    final cue = this.cue;
    if (cue != null) return cues.play(cue);
    AppHaptics.play(haptic);
  }
}

/// The beats of [intro] the clock passed going from [from] to [to]: after
/// the first and up to the second.
List<PaywallIntroBeat> paywallIntroBeatsBetween(
  PaywallIntro intro,
  double from,
  double to,
) => [
  for (final beat in intro.beats)
    if (beat.at > from && beat.at <= to) beat,
];

/// How long an intro's [PaywallIntro.tag] stays over the layout after the
/// hand over, the fade at its end included.
const double paywallIntroTagSeconds = 2.6;

/// How much of the tag shows [sinceHandover] seconds after the hand over,
/// 0 to 1: it pops in as the layout's mascot does and fades at the end.
double paywallIntroTagPresence(double sinceHandover) {
  if (sinceHandover <= 0 || sinceHandover >= paywallIntroTagSeconds) return 0;
  return math.min(
    phase(sinceHandover, 0.1, 0.34),
    1 -
        phase(
          sinceHandover,
          paywallIntroTagSeconds - 0.3,
          paywallIntroTagSeconds,
        ),
  );
}

/// The smallest face in a layout that counts as its mascot. A face inside
/// a feature preview is smaller.
const double paywallIntroLandingMinFace = 64;

/// The box an intro draws its mascot in, [leave] of the way out (0 to 1).
///
/// It goes from [from], where the intro had it, down to nothing at the
/// foot of [landing], which is where the layout's own mascot pops up from.
/// At one there is nothing left to draw. With no [landing] it goes down to
/// its own foot.
Rect paywallIntroLeaveBox({
  required Rect from,
  required Rect? landing,
  required double leave,
}) {
  if (leave <= 0) return from;
  final foot = (landing ?? from).bottomCenter;
  final eased = Curves.easeInOutCubic.transform(leave.clamp(0, 1).toDouble());
  return Rect.lerp(
    from,
    Rect.fromCenter(center: foot, width: 0, height: 0),
    eased,
  )!;
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
    case PaywallEntranceCue.print:
      cues.print();
    case PaywallEntranceCue.rise:
      cues.play(PaywallCue.rise);
    case PaywallEntranceCue.none:
      break;
  }
}

/// What the layout's frame tells the intro playing over it.
class PaywallIntroHandle {
  /// Which top corner the layout's close cross is in. The intro's own
  /// cross sits in the same one.
  bool closeOnLeft = false;

  /// Where the layout's mascot stands at rest, in the host's coordinates.
  /// See [PaywallIntroScope.landing].
  Rect? landing;

  /// How many seconds of its own clock the layout keeps its entrance
  /// quiet for: [PaywallIntro.quietAfter] of the intro playing.
  double quietFor = 0;
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

  /// The intro's own layer is gone.
  bool _isOver = false;

  /// Nothing of the intro is left, its tag included, and the clock stops.
  bool _isDone = false;

  /// The second up to which beats have played, and the second the layout
  /// was last searched for its mascot.
  double _heard = -1;
  double _looked = -1;

  final GlobalKey _layoutKey = GlobalKey();

  /// The layout's mascot, once found.
  RenderBox? _mascot;

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
    final finishes = !_isDone && t >= _lastSecond(intro);
    _look(t, intro);
    if (!PaywallMuted.of(context)) {
      final cues = getIt<PaywallCues>();
      // The reveal's beat is what the hand over feels like. Nothing here
      // vibrates as an alarm does.
      for (final beat in paywallIntroBeatsBetween(intro, _heard, t)) {
        beat.play(cues);
      }
    }
    _heard = t;
    if (finishes) _ticker.stop();
    _clock.tell();
    if (!handsOver && !ends && !finishes) return;
    setState(() {
      _hasHandedOver = _hasHandedOver || handsOver;
      _isOver = _isOver || ends;
      _isDone = _isDone || finishes;
    });
  }

  /// The second the last of the intro is gone: its own end, or its tag's.
  double _lastSecond(PaywallIntro intro) => intro.tag == null
      ? intro.seconds
      : math.max(intro.seconds, intro.handover + paywallIntroTagSeconds);

  /// Finds where the layout's mascot stands, a few times a second until
  /// it is found or the hand over has passed.
  void _look(double t, PaywallIntro intro) {
    if (_handle.landing != null || t > intro.handover) return;
    if (t - _looked < 0.12) return;
    _looked = t;
    _handle.landing = _findLanding();
  }

  /// The box of the largest face in the layout, where the layout laid it
  /// out. Moves the layout paints on top (an entrance, a bob) are left
  /// out, so this is where the mascot rests.
  Rect? _findLanding() {
    final host = context.findRenderObject();
    final root = _layoutKey.currentContext;
    if (host is! RenderBox || root is! Element) return null;
    Element? found;
    var edge = paywallIntroLandingMinFace;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is FaceWidget && widget.size >= edge) {
        found = element;
        edge = widget.size;
      }
      element.visitChildren(visit);
    }

    root.visitChildren(visit);
    final box = found?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    _mascot = box;
    var offset = Offset.zero;
    RenderObject? node = box;
    while (node != null && node != host) {
      final data = node.parentData;
      if (data is BoxParentData) offset += data.offset;
      node = node.parent;
    }
    return node == null ? null : offset & box.size;
  }

  /// Where the layout's mascot is painted now, its entrance and its bob
  /// included, or null while it is not there at about its full size. The
  /// tag stands by this, so it is never left pointing at nothing.
  Rect? _mascotNow() {
    final box = _mascot;
    final host = context.findRenderObject();
    if (box == null || !box.attached || !box.hasSize || host is! RenderBox) {
      return null;
    }
    final now = MatrixUtils.transformRect(
      box.getTransformTo(host),
      Offset.zero & box.size,
    );
    return now.width < box.size.width * 0.7 ? null : now;
  }

  void _skip() {
    final intro = _intro;
    if (intro == null || _isOver) return;
    final now = _clock.seconds;
    final to = paywallIntroSkip(intro, now);
    if (to == now) return;
    _skipped += to - now;
    _clock.seconds = to;
    // The moments a tap jumps over are not played. One that falls on the
    // second it lands on is, unless the intro has a cue for the tap.
    final skipCue = intro.skipCue;
    if (skipCue == null) {
      _heard = to - 1e-6;
    } else {
      _heard = to;
      if (!PaywallMuted.of(context)) getIt<PaywallCues>().play(skipCue);
    }
    _looked = -1;
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
      _handle.quietFor = intro?.quietAfter ?? 0;
      if (intro != null && !PaywallMuted.of(context)) {
        final cues = getIt<PaywallCues>();
        final score = intro.score;
        if (score == null) {
          playPaywallEntranceCue(cues, intro.cue);
        } else {
          cues.play(score);
        }
      }
    } else if (isStill && _intro != null && !_isOver) {
      // Motion was turned off half way: the intro goes at once.
      _hasHandedOver = true;
      _isOver = true;
      _isDone = true;
    }
    final isOnTop = ModalRoute.of(context)?.isCurrent ?? true;
    final shouldRun = _intro != null && !_isDone && isOnTop;
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
    final layout = context
        .getInheritedWidgetOfExactType<PaywallRouteInfo>()
        ?.layout;
    final tag =
        intro != null &&
            !_isDone &&
            !paywallIntroTaglessLayouts.contains(layout)
        ? intro.tag
        : null;
    final handover = intro?.handover ?? 0;

    return PaywallIntroPlay(
      intro: intro == null ? PaywallIntroId.none : widget.intro,
      handle: _handle,
      child: PaywallClockHold(
        isHeld: intro != null && !_hasHandedOver,
        child: Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(key: _layoutKey, child: widget.child),
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
            if (tag != null && _hasHandedOver)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: PaywallClockBuilder(
                      clock: _clock,
                      builder: (context, t, _) => _IntroTagLayer(
                        text: tag(),
                        landing: _mascotNow(),
                        presence: paywallIntroTagPresence(t - handover),
                      ),
                    ),
                  ),
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
                        handle: handle,
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

/// What the mascot is left saying, as a small tag by the layout's own
/// mascot with a tail pointing at it. It takes no room in the layout
/// and no touch, and it goes after a few seconds.
class _IntroTagLayer extends StatelessWidget {
  const _IntroTagLayer({
    required this.text,
    required this.landing,
    required this.presence,
  });

  final String text;
  final Rect? landing;
  final double presence;

  static const double _tail = 6;
  static const double _gap = 4;
  static const double _height = 28;
  static const double _maxWidth = 180;
  static const double _largestTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final at = landing;
    if (at == null || presence <= 0) return const SizedBox.shrink();
    // At a large text size a layout drops detail to fit, and the air this
    // tag stands in goes first. The tag is detail too.
    if (MediaQuery.textScalerOf(context).scale(1) > _largestTextScale) {
      return const SizedBox.shrink();
    }
    final colors = context.appColors;
    final screen = MediaQuery.sizeOf(context);
    const room = _gap + _tail + _height;
    // Over the mascot's head when there is air there, under its foot when
    // there is not. It never covers the status bar.
    final isAbove = at.top - room >= MediaQuery.viewPaddingOf(context).top + 2;
    final top = isAbove ? at.top - room : at.bottom + _gap;
    final left = (at.center.dx - _maxWidth / 2)
        .clamp(
          Spacing.s2,
          math.max(Spacing.s2, screen.width - _maxWidth - Spacing.s2),
        )
        .toDouble();
    final pop = AppCurves.easeBack.transform(presence);
    final pill = Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.s3),
      decoration: BoxDecoration(
        color: colors.onCanvas,
        borderRadius: BorderRadius.circular(Spacing.s3),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: AppTypography.small(
            colors.canvas,
          ).copyWith(fontWeight: FontWeight.w700, height: 1.2),
        ),
      ),
    );
    final tail = CustomPaint(
      size: const Size(12, _tail),
      painter: _TagTailPainter(colors.onCanvas, pointsDown: isAbove),
    );

    // The layout's own scaffold is not above this layer.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: _maxWidth,
            height: _height + _tail,
            child: Opacity(
              opacity: (presence * 2).clamp(0, 1),
              child: Transform.scale(
                scale: 0.6 + 0.4 * pop,
                alignment: isAbove
                    ? Alignment.bottomCenter
                    : Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: isAbove ? [pill, tail] : [tail, pill],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagTailPainter extends CustomPainter {
  const _TagTailPainter(this.color, {required this.pointsDown});

  final Color color;
  final bool pointsDown;

  @override
  void paint(Canvas canvas, Size size) {
    // One point under the tag's edge, so no seam shows between them.
    final base = pointsDown ? -1.0 : size.height + 1;
    final tip = pointsDown ? size.height : 0.0;
    final path = Path()
      ..moveTo(0, base)
      ..lineTo(size.width / 2, tip)
      ..lineTo(size.width, base)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TagTailPainter old) =>
      color != old.color || pointsDown != old.pointsDown;
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
