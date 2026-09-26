// Draws the reminder face images with the app's own face painter, so the
// lock screen shows the same Crit as the app.
//
// Run with: fvm flutter test tool/render_reminder_faces.dart
// ignore_for_file: avoid_print, cascade_invocations

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/design/faces/faces.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _size = 256;
const double _pad = 24;

/// The light palette's face colours (`lib/design/tokens/colors.dart`).
const Color _fill = Color(0xFFFFC93C);
const Color _ink = Color(0xFF1A140F);

void main() {
  test('render the reminder faces', () async {
    Directory('assets/reminder_faces').createSync(recursive: true);
    for (final face in LocalReminderFace.values) {
      final state = FaceState.values.byName(face.name);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _size, _size));
      canvas.translate(_pad, _pad);
      FacePainter(
        state: state,
        fillColor: _fill,
        strokeColor: _ink,
        inkColor: _ink,
      ).paint(canvas, const Size(_size - 2 * _pad, _size - 2 * _pad));
      final image = await recorder.endRecording().toImage(
        _size.toInt(),
        _size.toInt(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      File(face.assetPath).writeAsBytesSync(bytes);
      print('Wrote ${face.assetPath} (${bytes.length} bytes)');
    }
  });
}
