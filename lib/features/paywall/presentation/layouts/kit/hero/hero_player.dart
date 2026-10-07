import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

// The hand on a stage: the numbers that read a touch, the player that
// keeps what the hand chose, and the area that listens for it.

/// The line under a tap [y] points down a column of lines whose middles
/// are at [centres], or null when the tap is on none.
///
/// Every line answers a tap within [reach] of its middle, so each has a
/// tap area twice that tall however close the lines sit. Where two areas
/// overlap, the nearer line takes the tap.
int? heroLineAt(double y, List<double> centres, {double reach = 22}) {
  int? best;
  var nearest = double.infinity;
  for (final (i, centre) in centres.indexed) {
    final away = (y - centre).abs();
    if (away <= reach && away < nearest) {
      nearest = away;
      best = i;
    }
  }
  return best;
}

/// How far the card follows a finger that has moved [dragged] points
/// sideways: closely at first, then less and less, never past [limit].
double heroPullFor(double dragged, {double limit = 56}) =>
    limit * dragged / (limit * 1.6 + dragged.abs());

/// Whether a finger that moved [dragged] points and left at [velocity]
/// points a second has asked for another benefit, and which: 1 is the
/// next (a swipe to the left), -1 the previous, 0 neither.
int heroSwipeStep(double dragged, double velocity) {
  if (velocity.abs() >= 320) return velocity < 0 ? 1 : -1;
  if (dragged.abs() >= 44) return dragged < 0 ? 1 : -1;
  return 0;
}

/// How long the card takes to spring back when the finger lets go without
/// asking for another benefit.
const double heroSettleSeconds = 0.36;

/// The strip along the left edge of the screen where the route's own back
/// swipe listens.
const double heroBackEdge = 24;

/// One light haptic and the paywall's tick: what a change of benefit feels
/// and sounds like. The default of [HeroPlayer.onChange].
void heroChangeCue() {
  AppHaptics.selection();
  getIt<PaywallCues>().tick();
}

/// Plays a [HeroLoop] on a clock and keeps what the hand did to it: the
/// benefit last chosen, how long the loop has waited under a finger, and
/// the drag under way.
///
/// One player drives every part of a layout that follows the loop: the
/// stage, the pips, the lines, and anything of the layout's own. Each part
/// asks [frameAt] with the clock's second and draws that frame, so they
/// never disagree. Make one in your `State`, set [loop] in `build`, and
/// dispose it. It tells its listeners when the hand chose something, which
/// matters when nothing may move and no clock ticks.
///
/// Behaviour, the same for any table of turns:
/// - [touch] with an index (a tap on a line), a step (a swipe, wrapping),
///   or neither (a tap on the stage, which plays the current turn again).
/// - The chosen turn plays from its beginning, holds on its finished frame
///   for [HeroLoop.holdSeconds], and the loop goes on from the turn after.
/// - While a finger is down ([fingerDown]) the loop waits.
/// - A touch during the entrance waits for the entrance to end.
/// - When nothing may move, a touch cuts to that turn's resting frame.
class HeroPlayer extends ChangeNotifier {
  HeroPlayer({
    required this.clock,
    HeroLoop? loop,
    this.onChange = heroChangeCue,
  }) : loop = loop ?? HeroLoop(const []);

  /// The layout's clock: `scope.clock`.
  PaywallClock clock;

  /// The table being played. Safe to set on every build.
  HeroLoop loop;

  /// Called when a touch puts a different turn on the stage.
  final VoidCallback? onChange;

  /// What the hand last chose. Null while the loop runs untouched.
  HeroHand? get hand => _hand;
  HeroHand? _hand;

  /// How far the loop is behind the clock: it waits under a finger.
  HeroWait _wait = const HeroWait();

  /// The fingers down on the stage.
  final Set<int> _fingers = {};

  /// How far the finger has moved sideways in the drag under way.
  double _dragged = 0;
  bool _isDragging = false;

  /// The pull the finger let go of, and the clock second it did.
  double _released = 0;
  double _releasedAt = 0;

  /// True when nothing may move.
  bool get isStill => clock.isStill;

  /// The second the loop is at when the clock is at [t].
  double loopSeconds(double t) => clock.isStill ? t : _wait.loopSeconds(t);

  /// Everything to draw at clock second [t].
  HeroFrame frameAt(double t) => loop
      .frameAt(loopSeconds(t), isStill: clock.isStill, hand: _hand)
      .behind(clock.isStill ? 0 : _wait.behind(t));

  /// The frame at the clock's own second.
  HeroFrame get frame => frameAt(clock.value);

  /// The seconds a stage hands its atmosphere at clock second [t]: zero
  /// when nothing may move.
  double stageSeconds(double t) => clock.isStill ? 0 : t;

  /// The card's offset under the finger at clock second [t], in points.
  double pullAt(double t) {
    if (clock.isStill) return 0;
    if (_isDragging) return heroPullFor(_dragged);
    if (_released == 0) return 0;
    return _released *
        (1 -
            AppCurves.easeSpring.transform(
              phase(t, _releasedAt, _releasedAt + heroSettleSeconds),
            ));
  }

  /// A finger goes down on the stage: the loop waits under it.
  void fingerDown(PointerDownEvent event) {
    _fingers.add(event.pointer);
    _wait = _wait.down(clock.value, entranceEnd: loop.entranceEnd);
  }

  /// A finger lifts or is cancelled. The loop goes on when the last one
  /// has.
  void fingerUp(PointerEvent event) {
    if (!_fingers.remove(event.pointer) || _fingers.isNotEmpty) return;
    _wait = _wait.up(clock.value);
  }

  /// Takes a touch: a line by [index], a swipe by [step], or neither for a
  /// tap on the stage.
  void touch({int? index, int step = 0, double pull = 0}) {
    final t = loopSeconds(clock.value);
    final before = loop.chosenAt(t, hand: _hand);
    final hand = loop.touch(
      t,
      hand: _hand,
      index: index,
      step: step,
      pull: pull,
      isStill: clock.isStill,
    );
    if (hand == null) return;
    if (hand.index != before) onChange?.call();
    _hand = hand;
    notifyListeners();
  }

  /// A sideways drag across the stage starts, moves and ends. A fast or
  /// long one is a swipe to the next or the previous turn. One that never
  /// moved was a tap.
  void dragStart(DragStartDetails details) {
    _isDragging = true;
    _dragged = 0;
  }

  void dragUpdate(DragUpdateDetails details) {
    _dragged += details.primaryDelta ?? 0;
  }

  void dragEnd(DragEndDetails details) {
    final pull = clock.isStill ? 0.0 : heroPullFor(_dragged);
    final step = heroSwipeStep(_dragged, details.primaryVelocity ?? 0);
    final wasTap = _dragged.abs() < kTouchSlop;
    _isDragging = false;
    _dragged = 0;
    if (step != 0) {
      // The old card leaves from where the finger let go of it.
      _released = 0;
      touch(step: step, pull: pull);
    } else {
      _released = pull;
      _releasedAt = clock.value;
      // A touch at the edge is taken as a drag before it has moved. One
      // that never did move was a tap.
      if (wasTap) touch();
    }
  }

  void dragCancel() {
    _released = clock.isStill ? 0 : heroPullFor(_dragged);
    _releasedAt = clock.value;
    _isDragging = false;
    _dragged = 0;
  }
}

/// The area that answers the hand for a [HeroPlayer]: a tap plays the
/// current turn again, a sideways swipe goes to the next or the previous
/// one, and the loop waits while a finger is down.
///
/// Wrap the stage in it, or whatever a layout wants swiped. The lines do
/// the same job for anyone who does not swipe, so this is never the only
/// way. With [swipes] off it only takes the tap and the wait, for a layout
/// that uses a sideways drag for something of its own.
class HeroTouchArea extends StatelessWidget {
  const HeroTouchArea({
    required this.player,
    required this.child,
    this.swipes = true,
    super.key,
  });

  final HeroPlayer player;
  final Widget child;
  final bool swipes;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: player.fingerDown,
      onPointerUp: player.fingerUp,
      onPointerCancel: player.fingerUp,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                TapGestureRecognizer.new,
                (tap) => tap.onTap = player.touch,
              ),
          if (swipes)
            HeroStageDragRecognizer:
                GestureRecognizerFactoryWithHandlers<HeroStageDragRecognizer>(
                  HeroStageDragRecognizer.new,
                  (drag) => drag
                    ..onStart = player.dragStart
                    ..onUpdate = player.dragUpdate
                    ..onEnd = player.dragEnd
                    ..onCancel = player.dragCancel,
                ),
        },
        child: child,
      ),
    );
  }
}

/// A sideways drag that the route's back swipe cannot take. Along the left
/// edge of the screen the route listens for its own back swipe, and would
/// take a drag that starts there: so a touch in that strip is claimed at
/// once, and a swipe that starts on the stage never closes the screen.
///
/// Use it for any sideways drag in a layout: a stage, a divider, a reel.
class HeroStageDragRecognizer extends HorizontalDragGestureRecognizer {
  HeroStageDragRecognizer({this.edge = heroBackEdge});

  final double edge;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (event.position.dx < edge) resolve(GestureDisposition.accepted);
  }
}
