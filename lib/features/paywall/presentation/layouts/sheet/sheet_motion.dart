import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';

/// Every time in the Sheet layout, worked out from the clock's one number.
///
/// The entrance: the scrim comes down, the sheet rises, its handle widens,
/// the face pops over the edge. Then the lit row loops: on a limit row the
/// switch turns on and off again, on a locked row the badge shakes its
/// head once.
abstract final class SheetMotion {
  /// The second a still sheet rests on: the entrance is over and the row
  /// behind still shows the limit the user hit.
  static const double restAt = 1.6;

  /// The buy block comes in from this second, as the sheet lands.
  static const double buyBlockAt = 0.5;

  /// How long one loop of a limit row runs.
  static const double limitLoop = 9;

  /// How long one loop of a locked row runs.
  static const double lockedLoop = 8;

  /// How far the peeking face starts below its seat, in points.
  static const double peekDrop = 34;

  /// The angle the peeking face comes in at. It ends at zero.
  static const double peekTilt = 6 * math.pi / 180;

  /// How dark the scrim is, 0 to 1 of its full strength.
  static double scrim(double t) =>
      AppCurves.easeOut.transform(phase(t, 0, 0.5));

  /// How far up the sheet is: 0 below the screen, 1 in its seat. It passes
  /// 1 a little before it settles.
  static double rise(double t) =>
      AppCurves.easeSpring.transform(phase(t, 0.12, 0.82));

  /// The width of the handle, as a share of its full width.
  static double handle(double t) =>
      0.3 + 0.7 * AppCurves.easeSpring.transform(phase(t, 0.62, 1.22));

  /// How far the face has come over the edge: 0 hidden, 1 in its seat.
  static double peek(double t) =>
      AppCurves.easeSpring.transform(phase(t, 0.78, 1.33));

  /// Whether the limit row shows the limit lifted at [t].
  static bool limitLifted(double t) {
    final local = loopT(t, limitLoop);
    return local >= 2.2 && local < 8.3;
  }

  /// The locked badge's shake at [t], from -1 to 1. It is 0 outside the
  /// shake, so the badge rests upright.
  static double lockedShake(double t) {
    final p = phase(loopT(t, lockedLoop), 1.04, 1.48);
    if (p <= 0 || p >= 1) return 0;
    return math.sin(p * 3 * math.pi) * (1 - p);
  }
}
