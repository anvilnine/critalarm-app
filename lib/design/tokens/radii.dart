import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Corner radius tokens for Crit Alarm Design System.
/// 5 tiers: sm (10), md (18), lg (24), xl (32), full (9999).
abstract final class Radii {
  static const double sm = 10;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double full = 9999;

  // Backwards compatibility
  static const double xs = 2;
  static const double pill = full;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));

  /// The corner of a box set [inset] inside a box with corner [outer], so
  /// both curves keep the same centre and the gap between them stays even.
  /// Never below 0.
  static double concentric(double outer, double inset) =>
      math.max(0, outer - inset);

  // Backwards compatibility
  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius pillAll = fullAll;
}
