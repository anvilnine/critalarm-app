import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the watermark face', () {
    test('is brand yellow with the dark outline and ink in both themes', () {
      for (final colors in [AppColors.light, AppColors.dark]) {
        final c = ghostWatermarkColors(colors);
        expect(c.head, const Color(0xFFFFC93C));
        expect(c.outline, const Color(0xFF1A140F));
        expect(c.ink, const Color(0xFF1A140F));
      }
    });

    test('stays faint', () {
      expect(ghostWatermarkOpacity, greaterThan(0));
      expect(ghostWatermarkOpacity, lessThanOrEqualTo(0.2));
    });
  });
}
