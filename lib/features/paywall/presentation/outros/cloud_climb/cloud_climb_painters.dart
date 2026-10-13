// Canvas calls read better as separate statements than as cascades.
// ignore_for_file: cascade_invocations

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:critalarm/features/paywall/presentation/outros/cloud_climb/cloud_climb_timeline.dart';
import 'package:critalarm/features/paywall/presentation/outros/outro_parts.dart';
import 'package:flutter/widgets.dart';

typedef T = CloudClimbTimeline;

// One painter for each depth of the Cloud climb. Each draws the frame it is
// handed and repaints when the second changes.

abstract class _SecondPainter extends CustomPainter {
  const _SecondPainter(this.t);

  final double t;

  @override
  bool shouldRepaint(covariant _SecondPainter old) => old.t != t;
}

/// The ground: the layout's own picture, falling away. With no picture it
/// is a plain sheet in the end state's colour.
class CloudClimbGroundPainter extends _SecondPainter {
  const CloudClimbGroundPainter(super.t, {required this.ground, this.wall});

  final Color ground;
  final ui.Image? wall;

  @override
  void paint(Canvas canvas, Size size) {
    final rise = T.rise(t);
    if (rise >= size.height + 60) return;
    final to = Rect.fromLTWH(0, rise, size.width, size.height);
    final image = wall;
    if (image == null) {
      canvas.drawRect(to, Paint()..color = ground);
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      to,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

Path _nightPath(double edge, double width) => Path()
  ..moveTo(0, -2)
  ..lineTo(width, -2)
  ..lineTo(width, edge)
  ..quadraticBezierTo(width / 2, edge + T.nightDip, 0, edge)
  ..close();

/// The night with its stars and the far and mid clouds, clipped to the
/// night's curved edge.
class CloudClimbSkyPainter extends _SecondPainter {
  const CloudClimbSkyPainter(
    super.t, {
    required this.night,
    required this.star,
    required this.cream,
  });

  final Color night;
  final Color star;
  final Color cream;

  @override
  void paint(Canvas canvas, Size size) {
    if (!T.hasNight(t)) return;
    final path = _nightPath(T.nightEdge(t), size.width);
    canvas.drawPath(path, Paint()..color = night);
    canvas.save();
    canvas.clipPath(path);
    for (var i = 0; i < T.stars.length; i++) {
      paintOutroStar(canvas, T.starAt(i, t, size), T.stars[i].radius, star);
    }
    final dim = Color.lerp(night, cream, 0.26)!;
    for (var i = 0; i < T.far.length; i++) {
      final width = T.far[i].width;
      paintOutroCloud(
        canvas,
        T.farAt(i, t, size),
        width,
        width * T.farRatio,
        dim,
      );
    }
    final light = Color.lerp(night, cream, 0.62)!;
    for (var i = 0; i < T.mid.length; i++) {
      final width = T.mid[i].width;
      paintOutroCloud(
        canvas,
        T.midAt(i, t, size),
        width,
        width * T.midRatio,
        light,
      );
    }
    canvas.restore();
  }
}

/// The moon he climbs to, in the end state's colour, with a thin ring.
class CloudClimbMoonPainter extends _SecondPainter {
  const CloudClimbMoonPainter(
    super.t, {
    required this.ground,
    required this.ring,
  });

  final Color ground;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    if (T.moonProgress(t) <= 0) return;
    final centre = T.moonCentre(t, size);
    final radius = T.moonRadius(t, size);
    final ringAlpha = T.moonRingAlpha(t);
    if (ringAlpha > 0) {
      canvas.drawCircle(
        centre,
        radius + 14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = ring.withValues(alpha: ring.a * ringAlpha),
      );
    }
    canvas.drawCircle(centre, radius, Paint()..color = ground);
  }
}

/// The soft discs left behind under his cloud while it climbs.
class CloudClimbTrailPainter extends _SecondPainter {
  const CloudClimbTrailPainter(
    super.t, {
    required this.box,
    required this.color,
  });

  final Rect box;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grow = T.cloudGrow(t);
    if (grow <= 0 || T.cloudMelt(t) >= 1) return;
    final cy = box.center.dy + 92;
    const across = [-34.0, 26.0, -6.0];
    for (var i = 0; i < 3; i++) {
      final alpha = T.trailAlpha(t, i);
      if (alpha <= 0) continue;
      canvas.drawCircle(
        Offset(box.center.dx + across[i], cy + 44 + T.trailDrop(t, i)),
        (20 - i * 5) * grow,
        Paint()..color = color.withValues(alpha: color.a * alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CloudClimbTrailPainter old) =>
      old.t != t || old.box != box;
}

/// His cloud, with the small server box on it.
class CloudClimbCloudPainter extends _SecondPainter {
  const CloudClimbCloudPainter(
    super.t, {
    required this.box,
    required this.cloud,
    required this.ink,
    required this.dots,
  });

  final Rect box;
  final Color cloud;
  final Color ink;
  final Color dots;

  @override
  void paint(Canvas canvas, Size size) {
    final grow = T.cloudGrow(t);
    final melt = T.cloudMelt(t);
    if (grow <= 0 || melt >= 1) return;
    canvas.save();
    canvas.translate(box.center.dx, box.center.dy + 92);
    canvas.rotate(T.angle(t) * 0.6);
    canvas.scale(grow);
    // The cloud leaves by opacity, as one piece, so his outline shows
    // through it as it goes.
    canvas.saveLayer(
      const Rect.fromLTRB(-160, -80, 160, 90),
      Paint()..color = cloud.withValues(alpha: 1 - melt),
    );
    paintOutroCloud(canvas, Offset.zero, 250, 88, cloud);
    final alpha = T.boxAlpha(t);
    if (alpha > 0) _serverBox(canvas, const Offset(0, 10), 52, alpha);
    canvas.restore();
    canvas.restore();
  }

  void _serverBox(Canvas canvas, Offset c, double w, double alpha) {
    final h = w * 0.57;
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w, height: h),
      Radius.circular(w * 0.14),
    );
    canvas.saveLayer(
      box.outerRect.inflate(8),
      Paint()..color = ink.withValues(alpha: alpha),
    );
    canvas.drawRRect(box, Paint()..color = cloud);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, w * 0.054)
      ..strokeCap = StrokeCap.round
      ..color = ink;
    canvas.drawRRect(box, stroke);
    canvas.drawLine(
      Offset(c.dx - w * 0.3, c.dy + h * 0.2),
      Offset(c.dx + w * 0.02, c.dy + h * 0.2),
      stroke,
    );
    final glow = T.glow(t);
    final r = w * 0.065;
    canvas.drawCircle(
      Offset(c.dx + w * 0.17, c.dy - h * 0.08),
      r,
      Paint()..color = dots.withValues(alpha: dots.a * glow.a),
    );
    canvas.drawCircle(
      Offset(c.dx + w * 0.33, c.dy - h * 0.08),
      r,
      Paint()..color = dots.withValues(alpha: dots.a * glow.b),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CloudClimbCloudPainter old) =>
      old.t != t || old.box != box;
}

/// The near clouds, in front of him, thinning out as the moon grows.
class CloudClimbNearPainter extends _SecondPainter {
  const CloudClimbNearPainter(super.t, {required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = T.nearAlpha(t);
    if (T.rise(t) <= 0 || alpha <= 0) return;
    final paint = color.withValues(alpha: color.a * alpha);
    for (var i = 0; i < T.near.length; i++) {
      final at = T.nearAt(i, t, size);
      if (at.dy < -120 || at.dy > size.height + 120) continue;
      final width = T.near[i].width;
      paintOutroCloud(canvas, at, width, width * T.nearRatio, paint);
    }
  }
}
