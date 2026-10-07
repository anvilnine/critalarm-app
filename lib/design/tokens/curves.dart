import 'package:flutter/animation.dart';

/// Animation curves for Crit Alarm Design System.
abstract final class AppCurves {
  /// ease-out: cubic-bezier(.16,1,.3,1) for anything entering the frame.
  static const Curve easeOut = Cubic(0.16, 1, 0.3, 1);

  /// ease-spring: cubic-bezier(.34,1.2,.64,1) for hover and press
  /// micro-interactions.
  static const Curve easeSpring = Cubic(0.34, 1.2, 0.64, 1);

  /// ease-back: cubic-bezier(.34,1.56,.64,1) for a pop: something small
  /// that lands past its size and settles. It overshoots by about a tenth,
  /// so it is for a scale or a short hop, never for a fade or a colour.
  static const Curve easeBack = Cubic(0.34, 1.56, 0.64, 1);
}
