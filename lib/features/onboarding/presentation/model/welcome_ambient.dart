import 'package:critalarm/design/ambient/ambient_profile.dart';
import 'package:critalarm/design/ambient/ambient_shape.dart';
import 'package:flutter/foundation.dart';

/// How much faster or slower a shape runs than the pager, by its depth. A
/// shape near the front (small depth) trails the swipe a little and one far
/// back runs ahead of it, so the shapes spread out while they glide. Every
/// shape is home at a whole page value.
const double welcomeAmbientParallax = 0.4;

/// The progress of a shape of [depth] when the pager is [between] two pages
/// (0 at the first of them, 1 at the second).
@visibleForTesting
double welcomeShapeProgress(double between, double depth) {
  final t = between.clamp(0.0, 1.0);
  if (t == 0 || t == 1) return t;
  final rate = 1 + (depth - 0.5) * welcomeAmbientParallax;
  // A rate above 1 reaches the end early and stays there. A rate below 1 is
  // pulled up so it still arrives at exactly 1.
  return rate >= 1 ? (t * rate).clamp(0.0, 1.0) : t * rate + (1 - rate) * t * t;
}

/// The ambient profile for a pager at [pageValue] (`PageController.page`),
/// from one arrangement per page in [pages]. At a whole value it is that
/// page's own profile. Between two pages every shape glides from one
/// arrangement to the next with its own parallax, and the colours and the
/// canvas blend evenly.
AmbientProfile welcomeAmbientAt(List<AmbientProfile> pages, double pageValue) {
  assert(pages.isNotEmpty, 'There is a profile for at least one page.');
  final last = pages.length - 1;
  final value = pageValue.clamp(0.0, last.toDouble());
  final from = value.floor().clamp(0, last);
  final to = (from + 1).clamp(0, last);
  final between = value - from;
  if (from == to || between == 0) return pages[from];
  final a = pages[from];
  final b = pages[to];
  final blended = AmbientProfile.lerp(a, b, between);
  return AmbientProfile(
    canvas: blended.canvas,
    surfaceOpacity: blended.surfaceOpacity,
    shapes: List<AmbientShape>.unmodifiable([
      for (var i = 0; i < a.shapes.length; i++)
        AmbientShape.lerp(
          a.shapes[i],
          b.shapes[i],
          welcomeShapeProgress(between, a.shapes[i].depth),
        ),
    ]),
  );
}
