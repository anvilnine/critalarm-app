import 'dart:math' as math;

import 'package:critalarm/design/ambient/ambient_page.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

// A pass card grows into its page: the card's rect becomes the whole display,
// the label and the value slide to the page header, and the other cards step
// aside. This file holds the pure function that says where every part is at
// a point of the route (passFrameAt), the widgets that draw a frame, and the
// route that runs it.
//
// How the root and the route talk. The root draws its cards inside an
// AppPassStack, which places a PassOriginScope above them. A card that is
// tapped captures a PassOrigin (its rect, tone and thumbnail, plus the
// scope's PassHandoff) and the screen pushes the page route with it as
// `extra`. The route tells the handoff which pass is open and how far along
// the animation is. While it is open the card that was tapped draws nothing
// (the page stands in its place) and the other cards read the frame from the
// handoff, so they slide away and fade with the grow. Nothing about the
// transition reaches the screens.

/// The radius of a card's top corners (and of all four in the flat stack).
const double kPassCardRadius = 32;

/// How far a card's content sits from its sides.
const double kPassSidePadding = 20;

/// The label's distance from the top of a card.
const double kPassCardTopPadding = 18;

/// The label's distance from the top of the display on a page, past the
/// inset: ring top (5) plus ring (44) plus 22.
const double kPassHeaderTop = 71;

/// Value size on a card and on a page.
const double kPassCardValueSize = 30;
const double kPassPageValueSize = 42;

/// How far the other cards slide down while a page opens.
const double kPassOthersTravel = 120;

/// The thumbnail's right and top distance from its card, and its width.
const double kPassThumbRight = 18;
const double kPassThumbTop = 14;
const double kPassThumbWidth = 62;

const double _growMs = 520;
const double _openMs = 600;
const double _ringDelayMs = 200;
const double _ringMs = 300;
const double _bodyDelayMs = 300;
const double _bodyMs = 300;
const double _othersSlideMs = 450;

/// The cards are whole until the page covers this much of the way, then fade
/// so no sliver of one shows at the display's edge as the page fills it.
const double _othersFadeFrom = 0.9;
const double _thumbFadeStart = 0.15;
const double _thumbFadeEnd = 0.55;
const double _thumbFlightX = 112;
const double _thumbFlightY = 236;
const double _thumbGrow = 1.6;
const double _referenceWidth = 390;
const double _referenceHeight = 844;

double _unit(double x) => x.clamp(0.0, 1.0);

/// The display a page opens over: its size and the top inset.
@immutable
class PassDisplay {
  const PassDisplay(this.size, {this.safeTop = 0});

  /// A 390 by 844 phone with a 47 point inset, the reference phone.
  static const PassDisplay phone = PassDisplay(Size(390, 844), safeTop: 47);

  final Size size;
  final double safeTop;

  Rect get rect => Offset.zero & size;

  /// The left edge of the content column, which is `min(width, 560)` wide
  /// and centred.
  double get columnLeft => math.max(0, (size.width - 560) / 2);

  @override
  bool operator ==(Object other) =>
      other is PassDisplay && other.size == size && other.safeTop == safeTop;

  @override
  int get hashCode => Object.hash(size, safeTop);
}

/// What the route needs to grow a page from a card.
///
/// A card builds one when it is tapped, with its rect taken at that moment,
/// and the screen passes it to the route as the go_router `extra`.
@immutable
class PassOrigin {
  const PassOrigin({
    required this.pass,
    required this.rect,
    required this.tone,
    required this.label,
    required this.value,
    required this.display,
    this.thumbnail,
    this.bottomRadius = 0,
    this.reduceMotion = false,
    this.handoff,
  });

  final PassId pass;

  /// The card's rect in display coordinates.
  final Rect rect;

  final PassTone tone;

  /// The card's label and value. A page may read them to draw a header
  /// before its own data arrives.
  final String label;
  final String value;

  /// The display the card was tapped on.
  final PassDisplay display;

  /// Draws the card's thumbnail, which flies out as the page opens. Null for
  /// a card with none.
  final WidgetBuilder? thumbnail;

  /// The radius of the card's bottom corners: 0 in the overlapped stack and
  /// 32 in the flat one.
  final double bottomRadius;

  /// Whether the device asked to reduce motion when the card was tapped.
  final bool reduceMotion;

  /// The scope the card sat in, so the route can tell the root which card is
  /// open. Null when the card was not inside an `AppPassStack`.
  final PassHandoff? handoff;
}

/// Where every part of the transition is at one point of the route.
///
/// All positions are in display coordinates, for a page laid out at the
/// full display. See [passFrameAt].
@immutable
class PassFrame {
  const PassFrame({
    required this.rect,
    required this.topRadius,
    required this.bottomRadius,
    required this.grow,
    required this.headerOffset,
    required this.valueSize,
    required this.thumbOffset,
    required this.thumbScale,
    required this.thumbOpacity,
    required this.ringOpacity,
    required this.bodyOpacity,
    required this.othersOffset,
    required this.othersOpacity,
    this.aboveOffset = 0,
    this.openCardOpacity = 0,
    this.pageOpacity = 1,
    this.isClosing = false,
  });

  /// A page that has finished opening, or one that arrives without an origin.
  factory PassFrame.settled(
    PassDisplay display, {
    double pageOpacity = 1,
    double othersOpacity = 1,
    double openCardOpacity = 0,
    bool isClosing = false,
  }) => PassFrame(
    rect: display.rect,
    topRadius: 0,
    bottomRadius: 0,
    grow: 1,
    headerOffset: Offset.zero,
    valueSize: kPassPageValueSize,
    thumbOffset: Offset.zero,
    thumbScale: 1,
    thumbOpacity: 0,
    ringOpacity: 1,
    bodyOpacity: 1,
    othersOffset: 0,
    othersOpacity: othersOpacity,
    openCardOpacity: openCardOpacity,
    pageOpacity: pageOpacity,
    isClosing: isClosing,
  );

  /// The page's visible rect. It runs from the card's rect to the display.
  final Rect rect;
  final double topRadius;
  final double bottomRadius;

  /// 0 for the card and 1 for the page, after the grow curve.
  final double grow;

  /// How far the label and value sit from their place in the page header.
  final Offset headerOffset;

  /// The value's font size, 30 on the card and 42 on the page.
  final double valueSize;

  /// The thumbnail's pose, relative to where it sits on the card. It scales
  /// about its top right corner.
  final Offset thumbOffset;
  final double thumbScale;
  final double thumbOpacity;

  /// The back ring's opacity.
  final double ringOpacity;

  /// The page body's opacity.
  final double bodyOpacity;

  /// How far down the cards below the open one are, and how opaque every
  /// other card is. The page edge pushes the cards below it, so no card is
  /// ever cut by it.
  final double othersOffset;
  final double othersOpacity;

  /// How far the cards above the open one are moved, up (zero or less). The
  /// page's top edge pushes them the same way.
  final double aboveOffset;

  /// The opacity of the open card itself. Zero while a page stands in its
  /// place, and above zero only under reduce motion, where the root fades out
  /// before the page fades in.
  final double openCardOpacity;

  /// The opacity of the whole page. Below 1 only under reduce motion, where
  /// the finished page fades in over the empty root and nothing grows.
  final double pageOpacity;

  /// Whether the page is on its way back to the card, by the route closing or
  /// a finger dragging it. The page lets go of the canvas colour then, so the
  /// canvas is the root's again when the cards are home.
  final bool isClosing;

  /// The shadow around the card, which the page loses as it fills the
  /// display.
  double get shadowOpacity => 1 - grow;

  @override
  bool operator ==(Object other) =>
      other is PassFrame &&
      other.rect == rect &&
      other.topRadius == topRadius &&
      other.bottomRadius == bottomRadius &&
      other.grow == grow &&
      other.headerOffset == headerOffset &&
      other.valueSize == valueSize &&
      other.thumbOffset == thumbOffset &&
      other.thumbScale == thumbScale &&
      other.thumbOpacity == thumbOpacity &&
      other.ringOpacity == ringOpacity &&
      other.bodyOpacity == bodyOpacity &&
      other.othersOffset == othersOffset &&
      other.othersOpacity == othersOpacity &&
      other.aboveOffset == aboveOffset &&
      other.openCardOpacity == openCardOpacity &&
      other.pageOpacity == pageOpacity &&
      other.isClosing == isClosing;

  @override
  int get hashCode => Object.hash(
    rect,
    topRadius,
    bottomRadius,
    grow,
    headerOffset,
    valueSize,
    thumbOffset,
    thumbScale,
    thumbOpacity,
    ringOpacity,
    bodyOpacity,
    othersOffset,
    othersOpacity,
    aboveOffset,
    openCardOpacity,
    pageOpacity,
    isClosing,
  );
}

/// The transition at [progress] of the route (0 closed, 1 open).
///
/// The route runs [AppDurations.passPage] forward and [AppDurations.pass]
/// back, so [progress] stands for milliseconds: `progress * 600` on the way
/// in and `(1 - progress) * 520` on the way out. The numbers come from the
/// approved design:
///
/// - the rect, the value size and the label's place follow
///   [AppCurves.passGrow] over 520 ms; the radius follows the standard ease;
/// - the thumbnail flies with the grow and is gone by 55% of it, before the
///   page body starts, so two unlike copies of one picture are never on
///   screen together. On the way back it returns over the mirror of those
///   times;
/// - the back ring fades over 300 ms after 200 ms, the body over 300 ms after
///   300 ms (on the way out the ring waits 200 ms and the body goes first);
/// - the other cards are pushed by the page's edge: the ones below move down
///   as far as its bottom edge moves, the ones above move up as far as its top
///   edge moves. A card is never under the edge, so it is never cut, and on
///   the way back it returns whole after the edge has passed it. The ones
///   below also step 120 points down over 450 ms. They fade only as the page
///   nears the display's edges, so no sliver of one shows there.
///
/// With no [origin] (a deep link, a restored route) the page is already
/// where it belongs and the route uses the shell's own transition, so the
/// frame is the settled one. With [reduceMotion] nothing grows or moves: the
/// root's cards fade out over the first half of [progress] and the finished
/// page fades in over the second half, so the two never overlap.
PassFrame passFrameAt(
  double progress,
  PassOrigin? origin, {
  PassDisplay? display,
  bool reverse = false,
  bool? reduceMotion,
}) {
  final shown = display ?? origin?.display ?? PassDisplay.phone;
  if (origin == null) return PassFrame.settled(shown);
  final p = _unit(progress);
  if (reduceMotion ?? origin.reduceMotion) {
    final cards = 1 - _unit(p * 2);
    return PassFrame.settled(
      shown,
      pageOpacity: _unit((p - 0.5) * 2),
      othersOpacity: cards,
      openCardOpacity: cards,
      isClosing: reverse,
    );
  }

  // Milliseconds since the move began, in the direction it runs.
  final t = reverse ? (1 - p) * _growMs : p * _openMs;
  final u = _unit(t / _growMs);

  double ramp(double ms, {double delay = 0}) =>
      Curves.ease.transform(_unit((ms - delay) / _ringMs));

  final grow = reverse
      ? 1 - AppCurves.passGrow.transform(u)
      : AppCurves.passGrow.transform(u);
  final radius = reverse
      ? 1 - Curves.ease.transform(u)
      : Curves.ease.transform(u);

  final ring = reverse
      ? 1 - ramp(t, delay: _ringDelayMs)
      : ramp(t, delay: _ringDelayMs);
  final body = reverse
      ? 1 - Curves.ease.transform(_unit(t / _bodyMs))
      : Curves.ease.transform(_unit((t - _bodyDelayMs) / _bodyMs));
  assert(_ringMs == _bodyMs, 'ring and body share one fade length');

  final slide = AppCurves.passGrow.transform(_unit(t / _othersSlideMs));

  // Opening the thumbnail is whole at first and gone by the time the page
  // body starts. Closing it is the same run backwards.
  double thumbAt(double x) =>
      1 - _unit((x - _thumbFadeStart) / (_thumbFadeEnd - _thumbFadeStart));
  final thumb = reverse ? thumbAt(1 - u) : thumbAt(u);
  final flight = math.min(
    1,
    math.min(
      shown.size.width / _referenceWidth,
      shown.size.height / _referenceHeight,
    ),
  );

  final labelFrom = Offset(
    origin.rect.left + kPassSidePadding,
    origin.rect.top + kPassCardTopPadding,
  );
  final labelTo = Offset(
    shown.columnLeft + kPassSidePadding,
    shown.safeTop + kPassHeaderTop,
  );

  final rect = Rect.lerp(origin.rect, shown.rect, grow)!;
  final step = reverse
      ? kPassOthersTravel * (1 - slide)
      : kPassOthersTravel * slide;

  return PassFrame(
    rect: rect,
    topRadius: kPassCardRadius * (1 - radius),
    bottomRadius: origin.bottomRadius * (1 - radius),
    grow: grow,
    headerOffset: (labelFrom - labelTo) * (1 - grow),
    valueSize:
        kPassCardValueSize + (kPassPageValueSize - kPassCardValueSize) * grow,
    thumbOffset: Offset(
      -_thumbFlightX * flight * grow,
      _thumbFlightY * flight * grow,
    ),
    thumbScale: 1 + _thumbGrow * grow,
    thumbOpacity: thumb,
    ringOpacity: ring,
    bodyOpacity: body,
    othersOffset: math.max(step, rect.bottom - origin.rect.bottom),
    othersOpacity: 1 - _unit((grow - _othersFadeFrom) / (1 - _othersFadeFrom)),
    aboveOffset: math.min(0, rect.top - origin.rect.top),
    isClosing: reverse,
  );
}

/// Tells the root's cards which pass is open and how far the route is.
///
/// One lives in each [PassOriginScope]. The route attaches while it is on
/// screen. The card that was opened draws nothing in the meantime, and the
/// others move with the frame.
class PassHandoff extends ChangeNotifier {
  PassId? _open;
  Animation<double>? _animation;
  PassFrame Function()? _frame;
  bool _disposed = false;

  /// The pass whose page is up, or null.
  PassId? get open => _open;

  /// The route's animation while a page is up.
  Animation<double>? get animation => _animation;

  /// The frame the route is at now, or null with no page up.
  PassFrame? get frame => _frame?.call();

  /// Called by the route when it is installed.
  void attach({
    required PassId pass,
    required Animation<double> animation,
    required PassFrame Function() frame,
  }) {
    _animation?.removeStatusListener(_onStatus);
    _open = pass;
    _animation = animation;
    _frame = frame;
    animation.addStatusListener(_onStatus);
    _notifyLater();
  }

  /// Called by the route when it is disposed.
  void detach(Animation<double> animation) {
    if (_animation != animation) return;
    animation.removeStatusListener(_onStatus);
    _clear();
  }

  // The page is gone the moment the route is back at the start, which is
  // also the frame the root's card comes back on.
  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _animation?.removeStatusListener(_onStatus);
      _clear();
    }
  }

  void _clear() {
    if (_open == null) return;
    _open = null;
    _animation = null;
    _frame = null;
    _notifyLater();
  }

  // A route installs while the navigator builds, and a listener may not ask
  // for a rebuild then. The page covers the card exactly on its first frame,
  // so one frame of delay shows nothing.
  void _notifyLater() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _animation?.removeStatusListener(_onStatus);
    super.dispose();
  }
}

/// Holds the [PassHandoff] for the cards below it. `AppPassStack` places one
/// above its cards, so a screen that draws a stack has nothing to wire.
class PassOriginScope extends StatefulWidget {
  const PassOriginScope({required this.child, this.handoff, super.key});

  final Widget child;

  /// A handoff made by the caller, which the scope uses and does not
  /// dispose. The gallery uses one to hold a transition at a chosen frame.
  final PassHandoff? handoff;

  /// The handoff of the nearest scope, or null.
  static PassHandoff? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PassOriginInherited>()?.handoff;

  @override
  State<PassOriginScope> createState() => _PassOriginScopeState();
}

class _PassOriginScopeState extends State<PassOriginScope> {
  PassHandoff? _own;

  PassHandoff get _handoff => widget.handoff ?? (_own ??= PassHandoff());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _PassOriginInherited(handoff: _handoff, child: widget.child);
}

class _PassOriginInherited extends InheritedWidget {
  const _PassOriginInherited({required this.handoff, required super.child});

  final PassHandoff handoff;

  @override
  bool updateShouldNotify(_PassOriginInherited oldWidget) =>
      handoff != oldWidget.handoff;
}

/// Hands the current [PassFrame] to the page below it. `AppPassPage` reads it.
class PassFrameScope extends InheritedWidget {
  const PassFrameScope({
    required this.frame,
    required this.origin,
    required super.child,
    super.key,
  });

  final PassFrame frame;

  /// Null when the page arrived without an origin.
  final PassOrigin? origin;

  /// The scope above [context], or null for a page shown on its own.
  static PassFrameScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PassFrameScope>();

  @override
  bool updateShouldNotify(PassFrameScope oldWidget) =>
      frame != oldWidget.frame || origin != oldWidget.origin;
}

/// Draws a page through [frame]: the card's shadow, then the page, clipped to
/// the frame's rect.
///
/// The page is laid out once at the display's size and revealed, so a heavy
/// body is not laid out again on each frame. The route and the gallery both
/// draw through this.
class PassGrow extends StatelessWidget {
  const PassGrow({
    required this.frame,
    required this.origin,
    required this.child,
    super.key,
  });

  final PassFrame frame;
  final PassOrigin? origin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = BorderRadius.vertical(
      top: Radius.circular(frame.topRadius),
      bottom: Radius.circular(frame.bottomRadius),
    );
    Widget page = ClipRRect(
      clipper: _FrameClipper(frame),
      child: child,
    );
    if (frame.pageOpacity < 1) {
      page = Opacity(opacity: frame.pageOpacity, child: page);
    }
    return PassFrameScope(
      frame: frame,
      origin: origin,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (origin != null && frame.shadowOpacity > 0)
            Positioned.fromRect(
              rect: frame.rect,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: origin!.tone.ground,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: colors.inkFixed.withValues(
                          alpha: 0.18 * frame.shadowOpacity,
                        ),
                        offset: const Offset(0, -8),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          page,
        ],
      ),
    );
  }
}

class _FrameClipper extends CustomClipper<RRect> {
  const _FrameClipper(this.frame);

  final PassFrame frame;

  @override
  RRect getClip(Size size) => RRect.fromRectAndCorners(
    frame.rect,
    topLeft: Radius.circular(frame.topRadius),
    topRight: Radius.circular(frame.topRadius),
    bottomLeft: Radius.circular(frame.bottomRadius),
    bottomRight: Radius.circular(frame.bottomRadius),
  );

  @override
  bool shouldReclip(_FrameClipper oldClipper) => oldClipper.frame != frame;
}

/// A go_router page for a Personalize pass page.
///
/// With an [origin] the page grows out of the card, and closes back into it.
/// Without one (a deep link, a restored route, a picker opened from a topic)
/// it takes the shell's slide and fade, because the header is already in
/// place and there is no card to come from. The iOS edge swipe back works in
/// both: the shrink follows the finger because the transition reads the
/// route's animation.
class PassPage<T> extends CustomTransitionPage<T> {
  // The base page has no const constructor.
  // ignore: prefer_const_constructors_in_immutables
  PassPage({
    required super.child,
    this.origin,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
         transitionDuration: AppDurations.passPage,
         reverseTransitionDuration: AppDurations.pass,
         transitionsBuilder: _unused,
       );

  /// The card the page grows from, or null.
  final PassOrigin? origin;

  /// The page builds its own transition in [_PassRoute].
  static Widget _unused(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;

  @override
  Route<T> createRoute(BuildContext context) => _PassRoute<T>(page: this);
}

class _PassRoute<T> extends PageRoute<T> with AmbientRoutePopGestureMixin<T> {
  _PassRoute({required this.page}) : super(settings: page);

  final PassPage<T> page;

  PassOrigin? get _origin => page.origin;

  bool get _isReduced {
    final query = navigator?.context
        .getInheritedWidgetOfExactType<MediaQuery>();
    return query?.data.disableAnimations ?? _origin?.reduceMotion ?? false;
  }

  @override
  Duration get transitionDuration {
    if (_origin == null) {
      return _isReduced ? Duration.zero : AppDurations.slow;
    }
    return _isReduced ? AppDurations.quick : AppDurations.passPage;
  }

  @override
  Duration get reverseTransitionDuration {
    if (_origin == null) {
      return _isReduced ? Duration.zero : AppDurations.slow;
    }
    return _isReduced ? AppDurations.quick : AppDurations.pass;
  }

  // The grown page paints its own ground over the whole display, so the
  // root can stop painting once it is up. The framework paints it through
  // the transition anyway.
  @override
  bool get opaque => _origin != null;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  void install() {
    super.install();
    final origin = _origin;
    final animation = this.animation;
    if (origin == null || animation == null) return;
    origin.handoff?.attach(
      pass: origin.pass,
      animation: animation,
      frame: () => passFrameAt(
        animation.value,
        origin,
        reverse: _isReversing(animation),
        reduceMotion: _isReduced,
      ),
    );
  }

  @override
  void dispose() {
    final animation = this.animation;
    if (animation != null) _origin?.handoff?.detach(animation);
    super.dispose();
  }

  bool _isReversing(Animation<double> animation) =>
      popGestureInProgress || animation.status == AnimationStatus.reverse;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: page.child,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final origin = _origin;
    if (origin == null) {
      return buildAmbientRouteTransitions(
        context: context,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    }
    // The shell's builder wraps the page in the iOS edge swipe. Asked with a
    // finished animation it adds no slide and no fade.
    final gestured = buildAmbientRouteTransitions(
      context: context,
      animation: kAlwaysCompleteAnimation,
      secondaryAnimation: kAlwaysDismissedAnimation,
      child: child,
    );
    final display = PassDisplay(
      MediaQuery.sizeOf(context),
      safeTop: MediaQuery.paddingOf(context).top,
    );
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: animation,
      child: gestured,
      builder: (context, child) => PassGrow(
        frame: passFrameAt(
          animation.value,
          origin,
          display: display,
          reverse: _isReversing(animation),
          reduceMotion: reduced,
        ),
        origin: origin,
        child: child!,
      ),
    );
  }
}
