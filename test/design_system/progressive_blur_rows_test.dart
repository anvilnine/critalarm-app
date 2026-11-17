import 'package:critalarm/design_system/widgets/progressive_blur.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('edgeBlurRows', () {
    test('a top edge is full at its top and clear at its bottom', () {
      final rows = edgeBlurRows(
        top: 50,
        bottom: 110,
        height: 60,
        plateau: 0,
        isTop: true,
        pixelRatio: 3,
      );
      expect(rows.full, 150);
      expect(rows.clear, 330);
    });

    test('a bottom edge is full at its bottom and clear at its top', () {
      final rows = edgeBlurRows(
        top: 700,
        bottom: 760,
        height: 60,
        plateau: 0,
        isTop: false,
        pixelRatio: 3,
      );
      expect(rows.full, 2280);
      expect(rows.clear, 2100);
    });

    test('the plateau moves the full row in from the edge', () {
      final top = edgeBlurRows(
        top: 50,
        bottom: 110,
        height: 60,
        plateau: 20,
        isTop: true,
        pixelRatio: 2,
      );
      expect(top.full, 140);
      final bottom = edgeBlurRows(
        top: 700,
        bottom: 760,
        height: 60,
        plateau: 20,
        isTop: false,
        pixelRatio: 2,
      );
      expect(bottom.full, 1480);
    });

    test('a plateau longer than the strip stops at its far end', () {
      final rows = edgeBlurRows(
        top: 50,
        bottom: 110,
        height: 60,
        plateau: 90,
        isTop: true,
        pixelRatio: 2,
      );
      expect(rows.full, rows.clear);
    });

    test('a strip drawn at 80 percent keeps its rows on what is drawn', () {
      // Laid out 60 high with a plateau of 20, drawn 48 high from screen
      // row 600. The rows follow the screen, and the plateau shrinks too.
      final rows = edgeBlurRows(
        top: 600,
        bottom: 648,
        height: 60,
        plateau: 20,
        isTop: false,
        pixelRatio: 2.5,
      );
      expect(rows.full, (648 - 16) * 2.5);
      expect(rows.clear, 1500);
    });

    test('rows count from the top of the buffer the strip draws into', () {
      // An emulated window draws into its own buffer, here starting at
      // screen row 37. A strip from 37 to 126 then runs from buffer row 0.
      final rows = edgeBlurRows(
        top: 37,
        bottom: 126,
        height: 89,
        plateau: 0,
        isTop: true,
        pixelRatio: 2,
        origin: 37,
      );
      expect(rows.full, 0);
      expect(rows.clear, 178);
    });

    test('a strip with no height has no plateau', () {
      final rows = edgeBlurRows(
        top: 40,
        bottom: 40,
        height: 0,
        plateau: 10,
        isTop: true,
        pixelRatio: 2,
      );
      expect(rows.full, 80);
      expect(rows.clear, 80);
    });
  });
}
