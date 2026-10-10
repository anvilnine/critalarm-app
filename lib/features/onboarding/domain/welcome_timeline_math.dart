import 'package:flutter/animation.dart';

// Small helpers the welcome timelines share. A timeline is a table of stops
// and this reads one value off it.

/// A value that moves through [stops], one after another. Each stop is a loop
/// fraction and the value there. Before the first stop and after the last the
/// value holds. Between two stops it follows [curve], once per stretch, the
/// way a CSS keyframe list does.
double welcomeThrough(
  double fraction,
  List<(double, double)> stops, {
  Curve curve = Curves.linear,
}) {
  if (fraction <= stops.first.$1) return stops.first.$2;
  for (var i = 1; i < stops.length; i++) {
    final (to, toValue) = stops[i];
    if (fraction <= to) {
      final (from, fromValue) = stops[i - 1];
      final progress = (fraction - from) / (to - from);
      return fromValue + (toValue - fromValue) * curve.transform(progress);
    }
  }
  return stops.last.$2;
}
