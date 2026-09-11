import 'package:flutter/animation.dart';

/// Animation curves for Crit Alarm Design System.
abstract final class AppCurves {
  /// ease-out: cubic-bezier(.16,1,.3,1) for anything entering the frame.
  static const Curve easeOut = Cubic(0.16, 1, 0.3, 1);

  /// ease-spring: cubic-bezier(.34,1.2,.64,1) for hover and press
  /// micro-interactions.
  static const Curve easeSpring = Cubic(0.34, 1.2, 0.64, 1);
}
