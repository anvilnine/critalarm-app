import 'package:critalarm/design/faces/face_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FacePainter.pupilOnWhite', () {
    const lightInk = Color(0xFFF7F1EA);
    const darkInk = Color(0xFF1A140F);

    test('a dark ink stays as it is', () {
      expect(FacePainter.pupilOnWhite(darkInk), darkInk);
    });

    test('a light ink turns dark, so the pupil shows on the white', () {
      final pupil = FacePainter.pupilOnWhite(lightInk);
      expect(pupil, isNot(lightInk));
      expect(pupil.computeLuminance(), lessThan(0.2));
    });
  });
}
