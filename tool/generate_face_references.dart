// Developer tool helper for generating reference screenshots.
// ignore_for_file: avoid_print, cascade_invocations

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum MascotState {
  clear,
  watching,
  warning,
  alarm,
  acknowledged,
  connecting,
  disconnected,
  sleeping,
  closed,
}

void _paintMascotFace(Canvas canvas, Size size, MascotState state) {
  final scale = size.width / 200.0;
  canvas
    ..save()
    ..scale(scale, scale);

  final isAlarmed = state == MascotState.alarm;

  const headRect = Rect.fromLTWH(12, 12, 176, 176);
  final headRRect = RRect.fromRectAndRadius(
    headRect,
    const Radius.circular(66),
  );

  final headFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFFFC93C);
  canvas.drawRRect(headRRect, headFillPaint);

  final headStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = isAlarmed ? 12.0 : 10.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF1A140F);
  canvas.drawRRect(headRRect, headStrokePaint);

  final featureStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = isAlarmed ? 11.0 : 10.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF1A140F);

  final featureFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFF1A140F);

  switch (state) {
    case MascotState.clear:
      // Round eyes r 11 at (70, 90) and (130, 90)
      canvas.drawCircle(const Offset(70, 90), 11, featureFillPaint);
      canvas.drawCircle(const Offset(130, 90), 11, featureFillPaint);

      // Easy mouth M70 128 Q100 148 130 128
      final mouth = Path()
        ..moveTo(70, 128)
        ..quadraticBezierTo(100, 148, 130, 128);
      canvas.drawPath(mouth, featureStrokePaint);

    case MascotState.watching:
      // Pupils r 11 at (80, 92) and (140, 92)
      canvas.drawCircle(const Offset(80, 92), 11, featureFillPaint);
      canvas.drawCircle(const Offset(140, 92), 11, featureFillPaint);

      // Raised left brow M56 68 Q70 58 86 64
      final brow = Path()
        ..moveTo(56, 68)
        ..quadraticBezierTo(70, 58, 86, 64);
      canvas.drawPath(brow, featureStrokePaint);

      // Flat mouth M84 134 H118
      final mouth = Path()
        ..moveTo(84, 134)
        ..lineTo(118, 134);
      canvas.drawPath(mouth, featureStrokePaint);

    case MascotState.warning:
      // Pinching brows M54 70 L84 58 and M116 58 L146 70
      final brows = Path()
        ..moveTo(54, 70)
        ..lineTo(84, 58)
        ..moveTo(116, 58)
        ..lineTo(146, 70);
      canvas.drawPath(brows, featureStrokePaint);

      // Round eyes r 11 at (70, 92) and (130, 92)
      canvas.drawCircle(const Offset(70, 92), 11, featureFillPaint);
      canvas.drawCircle(const Offset(130, 92), 11, featureFillPaint);

      // Wavering mouth M72 138 Q86 124 100 138 T128 138
      final mouth = Path()
        ..moveTo(72, 138)
        ..quadraticBezierTo(86, 124, 100, 138)
        ..quadraticBezierTo(114, 152, 128, 138);
      canvas.drawPath(mouth, featureStrokePaint);

    case MascotState.alarm:
      // Downward angled brows M50 58 L84 68 and M116 68 L150 58
      final brows = Path()
        ..moveTo(50, 58)
        ..lineTo(84, 68)
        ..moveTo(116, 68)
        ..lineTo(150, 58);
      canvas.drawPath(brows, featureStrokePaint);

      // Wide outer eyes r 17 with stroke 11 at (70, 94) and (130, 94)
      canvas.drawCircle(const Offset(70, 94), 17, featureStrokePaint);
      canvas.drawCircle(const Offset(130, 94), 17, featureStrokePaint);

      // Inner pupil dots r 6 at (70, 94) and (130, 94)
      canvas.drawCircle(const Offset(70, 94), 6, featureFillPaint);
      canvas.drawCircle(const Offset(130, 94), 6, featureFillPaint);

      // Open mouth ellipse cx 100 cy 142 rx 17 ry 22
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(100, 142),
          width: 34,
          height: 44,
        ),
        featureFillPaint,
      );

    case MascotState.acknowledged:
      // Closed eyes arches M56 94 Q70 78 84 94 and M116 94 Q130 78 144 94
      final eyes = Path()
        ..moveTo(56, 94)
        ..quadraticBezierTo(70, 78, 84, 94)
        ..moveTo(116, 94)
        ..quadraticBezierTo(130, 78, 144, 94);
      canvas.drawPath(eyes, featureStrokePaint);

      // Gentle mouth M76 128 Q100 146 124 128
      final mouth = Path()
        ..moveTo(76, 128)
        ..quadraticBezierTo(100, 146, 124, 128);
      canvas.drawPath(mouth, featureStrokePaint);

    case MascotState.connecting:
      // Round eyes r 11 at (70, 90) and (130, 90)
      canvas.drawCircle(const Offset(70, 90), 11, featureFillPaint);
      canvas.drawCircle(const Offset(130, 90), 11, featureFillPaint);

      // Flat mouth M84 134 H118
      final mouth = Path()
        ..moveTo(84, 134)
        ..lineTo(118, 134);
      canvas.drawPath(mouth, featureStrokePaint);

    case MascotState.disconnected:
      // Flat eyes M56 94 H84 and M116 94 H144
      final eyes = Path()
        ..moveTo(56, 94)
        ..lineTo(84, 94)
        ..moveTo(116, 94)
        ..lineTo(144, 94);
      canvas.drawPath(eyes, featureStrokePaint);

      // Flat mouth M76 134 H124
      final mouth = Path()
        ..moveTo(76, 134)
        ..lineTo(124, 134);
      canvas.drawPath(mouth, featureStrokePaint);

    case MascotState.sleeping:
      // Drooping eyes M56 90 Q70 102 84 90 and M116 90 Q130 102 144 90
      final eyes = Path()
        ..moveTo(56, 90)
        ..quadraticBezierTo(70, 102, 84, 90)
        ..moveTo(116, 90)
        ..quadraticBezierTo(130, 102, 144, 90);
      canvas.drawPath(eyes, featureStrokePaint);

      // Gentle smile M88 136 Q100 140 112 136
      final mouth = Path()
        ..moveTo(88, 136)
        ..quadraticBezierTo(100, 140, 112, 136);
      canvas.drawPath(mouth, featureStrokePaint);

    case MascotState.closed:
      // Wide closed eye arches M52 94 Q70 74 88 94 and M112 94 Q130 74 148 94
      final eyes = Path()
        ..moveTo(52, 94)
        ..quadraticBezierTo(70, 74, 88, 94)
        ..moveTo(112, 94)
        ..quadraticBezierTo(130, 74, 148, 94);
      canvas.drawPath(eyes, featureStrokePaint);

      // Wide celebration smile M62 122 Q100 164 138 122
      final mouth = Path()
        ..moveTo(62, 122)
        ..quadraticBezierTo(100, 164, 138, 122);
      canvas.drawPath(mouth, featureStrokePaint);
  }

  canvas.restore();
}

void main() {
  test('Generate Flutter reference screenshots at 240px', () async {
    final dir = Directory('docs/mascot/reference');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    for (final state in MascotState.values) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        const Rect.fromLTWH(0, 0, 240, 240),
      );

      _paintMascotFace(canvas, const Size(240, 240), state);

      final picture = recorder.endRecording();
      final image = await picture.toImage(240, 240);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file = File('docs/mascot/reference/${state.name}.png');
      file.writeAsBytesSync(bytes);
      print('Wrote ${file.path} (${bytes.length} bytes)');
    }
  });
}
