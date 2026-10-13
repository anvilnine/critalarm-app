import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_pieces.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_timeline.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

typedef T = BreakLiftTimeline;

const _size = Size(390, 844);

Future<ui.Image> _solid(Color color, Size size) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Offset.zero & size, Paint()..color = color);
  return recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
}

Future<ByteData> _render(
  BreakLiftPieceBatch batch,
  double t,
  ui.Image? wall,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(Offset.zero & _size, Paint()..color = const Color(0xFF0000FF));
  batch.paint(
    canvas,
    _size,
    t: t,
    pieces: T.pieces(_size),
    wall: wall,
    ground: const Color(0xFF00FF00),
    edge: const Color(0xFF000000),
  );
  final image = await recorder.endRecording().toImage(390, 844);
  return (await image.toByteData())!;
}

/// The pixel at the middle of piece [i] at the start of its flight.
Offset _middle(int i) => T.pieces(_size)[i].centre;

List<int> _pixel(ByteData data, Offset at) {
  final i = ((at.dy.round() * 390) + at.dx.round()) * 4;
  return [for (var n = 0; n < 4; n++) data.getUint8(i + n)];
}

void main() {
  test('a piece shows its part of the picture at full strength', () async {
    final wall = await _solid(const Color(0xFFFF0000), _size);
    final batch = BreakLiftPieceBatch();
    final data = await _render(batch, T.hit, wall);
    final px = _pixel(data, _middle(20));
    expect(px[0], greaterThan(240), reason: '$px');
    expect(px[2], lessThan(15), reason: '$px');
    batch.dispose();
  });

  test(
    'a fading piece is the picture times its alpha over what is behind',
    () async {
      final wall = await _solid(const Color(0xFFFF0000), _size);
      final batch = BreakLiftPieceBatch();
      // Half way through the fade, where the pieces are half solid.
      const t = T.hit + 0.575;
      final alpha = T.flightOf(T.pieces(_size)[20], t, k: 1).alpha;
      expect(alpha, closeTo(0.5, 0.01));
      final data = await _render(batch, t, wall);
      // Find a pixel that is inside a piece: sample the shifted middle.
      final f = T.flightOf(T.pieces(_size)[20], t, k: 1);
      final px = _pixel(data, _middle(20) + f.shift);
      // Red at half over blue: about 128 red and 128 blue, not brighter.
      expect(px[0], inInclusiveRange(110, 150), reason: '$px');
      expect(px[2], inInclusiveRange(110, 150), reason: '$px');
      batch.dispose();
    },
  );

  test('with no picture a piece is the ground colour', () async {
    final batch = BreakLiftPieceBatch();
    final data = await _render(batch, T.hit, null);
    final px = _pixel(data, _middle(20));
    expect(px[1], greaterThan(240), reason: '$px');
    batch.dispose();
  });
}
