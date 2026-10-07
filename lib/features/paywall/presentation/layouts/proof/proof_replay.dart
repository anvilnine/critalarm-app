import 'dart:math' as math;

// The replay the Proof layout plays on its topic list, as numbers worked out
// from the clock. Nothing here draws: the card reads a [ProofFrame] and
// places what it says.

/// The beats of one replay, in the order they play.
enum ProofBeat {
  /// The free plan as it is: the cap is full and the next row is locked.
  capped,

  /// A finger taps the locked row's switch. The knob starts and comes back.
  refusedTap,

  /// The switch shakes its head. Only the switch moves.
  shake,

  /// The count in the card header pulses: this is why.
  note,

  /// The paid plan arrives: the lock goes and the count has no limit.
  lifted,

  /// The same tap again, and this time the switch goes on. One tap for
  /// each locked row.
  switchOn,

  /// Every switch is on. The frame the replay rests on.
  allOn,

  /// Back to the start, for the next loop.
  reset,
}

/// How long one replay is, in seconds.
const double proofLoopSeconds = 9;

/// The second of the layout's clock the first replay starts at, after the
/// entrance.
const double proofReplayStartsAt = 0.7;

/// The second of the layout's clock that rests on [ProofBeat.allOn].
const double proofRestAt = proofReplayStartsAt + proofLoopSeconds * 0.8;

/// When each beat starts, in seconds into a replay with [lockedRows] rows
/// to switch on. Sorted by time, and one entry per beat.
List<(ProofBeat, double)> proofBeatTable({int lockedRows = 2}) => [
  (ProofBeat.capped, 0),
  (ProofBeat.refusedTap, _refusedTapAt),
  (ProofBeat.shake, _shakeAt),
  (ProofBeat.note, _noteAt),
  (ProofBeat.lifted, _liftedAt),
  (ProofBeat.switchOn, _firstTapAt),
  (ProofBeat.allOn, _allOnAt(lockedRows)),
  (ProofBeat.reset, _resetAt),
];

/// The beat playing [seconds] into a replay.
ProofBeat proofBeatAt(double seconds, {int lockedRows = 2}) {
  var beat = ProofBeat.capped;
  for (final (next, start) in proofBeatTable(lockedRows: lockedRows)) {
    if (seconds >= start) beat = next;
  }
  return beat;
}

const double _refusedTapAt = 0.76;
const double _shakeAt = 1.22;
const double _shakeEnds = 1.94;
const double _noteAt = 1.55;
const double _noteEnds = 2.3;
const double _liftedAt = 2.61;
const double _firstTapAt = 3.38;
const double _resetAt = 8.28;
const double _resetEnds = 8.55;

/// A tap ring grows in, presses and lets go over this long.
const double _tapSeconds = 0.68;

/// How far into a tap the finger is down and the switch answers.
const double _tapLands = 0.27;

/// The gap between the taps on two locked rows.
double _tapGap(int lockedRows) =>
    lockedRows <= 1 ? 0 : math.min(1.08, 2.7 / (lockedRows - 1));

double _tapAt(int row, int lockedRows) =>
    _firstTapAt + row * _tapGap(lockedRows);

double _allOnAt(int lockedRows) =>
    _tapAt(math.max(lockedRows, 1) - 1, lockedRows) + _tapSeconds;

double _window(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0);

/// Everything the card needs to draw one instant of the replay.
class ProofFrame {
  const ProofFrame._(this.seconds, this.lockedRows);

  /// The frame [seconds] into a replay with [lockedRows] rows past the cap.
  factory ProofFrame.at(double seconds, {int lockedRows = 2}) =>
      ProofFrame._(seconds, math.max(lockedRows, 1));

  /// The frame the layout's own clock [t] shows. Before the first replay
  /// starts it is the capped frame, and after that the replay loops.
  factory ProofFrame.atClock(double t, {int lockedRows = 2}) {
    final local = t - proofReplayStartsAt;
    return ProofFrame.at(
      local <= 0 ? 0 : local % proofLoopSeconds,
      lockedRows: lockedRows,
    );
  }

  final double seconds;
  final int lockedRows;

  ProofBeat get beat => proofBeatAt(seconds, lockedRows: lockedRows);

  /// 1 while the replay holds its result, falling to 0 as it resets.
  double get _held => 1 - _window(seconds, _resetAt, _resetEnds);

  /// How far the paid plan has arrived, 0 to 1: the locks fade and the
  /// count changes with it.
  double get lifted => _window(seconds, _liftedAt, _liftedAt + 0.27) * _held;

  /// How far the limit bars have filled, 0 to 1, before any easing.
  double get barsFilled =>
      _window(seconds, _liftedAt, _liftedAt + 1.08) * _held;

  /// The scale of the count in the header. It swells twice and ends at 1.
  double get noteScale {
    final p = _window(seconds, _noteAt, _noteEnds);
    if (p <= 0 || p >= 1) return 1;
    // Two bumps, the second one smaller.
    final bump = math.sin(p * 2 * math.pi).abs();
    return 1 + (p < 0.5 ? 0.16 : 0.1) * bump;
  }

  /// How far sideways the first locked switch is, in points. Zero outside
  /// the shake, and zero when it ends.
  double get shakeDx {
    final p = _window(seconds, _shakeAt, _shakeEnds);
    if (p <= 0 || p >= 1) return 0;
    // Five swings that die away: left, right, left, right, left.
    return -6 * math.sin(p * 5 * math.pi) * (1 - p);
  }

  /// How far on locked row [row]'s switch is, 0 (off) to 1 (on). On the
  /// refused tap the first one starts, gets half way and comes back.
  double switchOn(int row) {
    final on =
        _window(
          seconds,
          _tapAt(row, lockedRows) + _tapLands,
          _tapAt(row, lockedRows) + _tapLands + 0.22,
        ) *
        _held;
    if (row != 0 || on > 0) return on;
    final nudge = _window(seconds, _refusedTapAt + _tapLands, _shakeAt + 0.1);
    if (nudge <= 0 || nudge >= 1) return 0;
    return 0.5 * math.sin(nudge * math.pi);
  }

  /// How far locked row [row] reads as ringing, 0 to 1: its chip and its
  /// face follow the switch a moment later.
  double rings(int row) =>
      _window(
        seconds,
        _tapAt(row, lockedRows) + _tapLands + 0.16,
        _tapAt(row, lockedRows) + _tapLands + 0.4,
      ) *
      _held;

  /// The tap ring on locked row [row]: how visible it is and how big,
  /// or null when no finger is on that row.
  ({double opacity, double scale})? tap(int row) {
    final starts = [
      if (row == 0) _refusedTapAt,
      _tapAt(row, lockedRows),
    ];
    for (final start in starts) {
      final p = (seconds - start) / _tapSeconds;
      if (p <= 0 || p >= 1) continue;
      // In over the first 30 percent, held to 55, out by the end.
      if (p < 0.3) {
        final q = p / 0.3;
        return (opacity: q, scale: 1.6 - 0.8 * q);
      }
      if (p < 0.55) return (opacity: 1, scale: 0.8);
      final q = (p - 0.55) / 0.45;
      return (opacity: 1 - q, scale: 0.8 + 0.9 * q);
    }
    return null;
  }
}
