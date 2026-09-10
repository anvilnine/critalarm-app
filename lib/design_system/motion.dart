import 'package:flutter/widgets.dart';

/// Motion helpers: snappy, mechanical, no bounce.
/// Decorative animation collapses to an instant cut when the OS "reduce
/// motion" accessibility setting is on.
extension AppMotion on BuildContext {
  /// True when the platform asks apps to minimize non-essential motion.
  bool get reduceMotion => MediaQuery.maybeOf(this)?.disableAnimations ?? false;

  /// [full] normally, [Duration.zero] under reduced motion — so implicit
  /// animations (AnimatedSwitcher/AnimatedScale/…) cut instead of tween.
  Duration motion(Duration full) => reduceMotion ? Duration.zero : full;
}
