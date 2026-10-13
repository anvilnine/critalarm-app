import 'dart:ui' as ui;

import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_painters.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_pieces.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef T = BreakLiftTimeline;

/// A canvas that does nothing and counts what the painter asks of it.
class _CountingCanvas implements Canvas {
  final Map<String, int> calls = {};
  int blurredPaints = 0;

  void _count(String name, [Paint? paint]) {
    calls[name] = (calls[name] ?? 0) + 1;
    if (paint?.maskFilter != null) blurredPaints++;
  }

  @override
  void saveLayer(Rect? bounds, Paint paint) => _count('saveLayer', paint);

  @override
  void drawPath(Path path, Paint paint) => _count('drawPath', paint);

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      _count('drawCircle', paint);

  @override
  void drawRect(Rect rect, Paint paint) => _count('drawRect', paint);

  @override
  void drawRRect(RRect rrect, Paint paint) => _count('drawRRect', paint);

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) =>
      _count('drawImageRect', paint);

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) => _count('clipPath');

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) =>
      _count('drawVertices', paint);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _size = Size(390, 844);
const _colors = BreakLiftRingColors(
  paper: Color(0xFFFFFFFF),
  line: Color(0xFF000000),
  edge: Color(0xFF111111),
  night: Color(0xFF1A1613),
  cream: Color(0xFFF5F0E6),
  yellow: Color(0xFFFFC83A),
  cobalt: Color(0xFF2233CC),
  onCobalt: Color(0xFFFFFFFF),
  ground: Color(0xFFFFC83A),
);

void main() {
  test(
    'with the wall picture it is still one vertices call and no layer',
    () async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        Offset.zero & _size,
        Paint()..color = const Color(0xFFFF0000),
      );
      final wall = await recorder.endRecording().toImage(390, 844);
      for (final t in [0.5, 0.9, 1.0]) {
        final canvas = _CountingCanvas();
        final pose = T.pose(
          t,
          size: _size,
          land: Rect.fromCenter(
            center: const Offset(195, 236),
            width: 174,
            height: 174,
          ),
        );
        _paint(canvas, t, pose, wall: wall);
        expect(canvas.calls['saveLayer'] ?? 0, 0);
        expect(canvas.calls['clipPath'] ?? 0, 0);
        expect(canvas.calls['drawImageRect'] ?? 0, 0);
        expect(canvas.blurredPaints, 0);
        expect(canvas.calls['drawVertices'], 1);
      }
    },
  );

  for (final t in [0.5, 0.9, 1.2, 1.65]) {
    test('painting at $t takes no layer, no blur and a few draw calls', () {
      final canvas = _CountingCanvas();
      final pose = T.pose(
        t,
        size: _size,
        land: Rect.fromCenter(
          center: const Offset(195, 236),
          width: 174,
          height: 174,
        ),
      );
      _paint(canvas, t, pose);
      expect(canvas.calls['saveLayer'] ?? 0, 0, reason: '${canvas.calls}');
      expect(canvas.blurredPaints, 0, reason: '${canvas.calls}');
      expect(canvas.calls['clipPath'] ?? 0, 0, reason: '${canvas.calls}');
      expect(canvas.calls['drawImageRect'] ?? 0, 0, reason: '${canvas.calls}');
      // All 56 pieces go in one call, their outlines in one more.
      expect(canvas.calls['drawVertices'] ?? 0, lessThanOrEqualTo(1));
      expect(canvas.calls['drawPath'] ?? 0, lessThanOrEqualTo(6));
    });
  }
}

void _paint(
  Canvas canvas,
  double t,
  BreakLiftRingPose pose, {
  ui.Image? wall,
}) {
  BreakLiftPainter(
    t: t,
    pieces: T.pieces(_size),
    batch: BreakLiftPieceBatch(),
    colors: _colors,
    crit: pose.box,
    lean: pose.angle,
    wall: wall,
  ).paint(canvas, _size);
}
