import 'package:critalarm/design/components/fitted_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fittedFontSize', () {
    test('a word that fits keeps its size', () {
      expect(
        fittedFontSize(fontSize: 56, longestWordWidth: 300, maxWidth: 320),
        56,
      );
    });

    test('a word wider than the room is scaled until it fits', () {
      // 56 px sets the word 400 wide. In 320 it needs 56 * 320 / 400.
      expect(
        fittedFontSize(fontSize: 56, longestWordWidth: 400, maxWidth: 320),
        closeTo(44.8, 0.001),
      );
    });

    test('it never grows past the size asked for', () {
      expect(
        fittedFontSize(fontSize: 56, longestWordWidth: 10, maxWidth: 1000),
        56,
      );
    });

    test(
      'it stops at the smallest size, so a huge text size stays legible',
      () {
        expect(
          fittedFontSize(fontSize: 56, longestWordWidth: 4000, maxWidth: 320),
          20,
        );
      },
    );

    test('an empty title keeps its size', () {
      expect(
        fittedFontSize(fontSize: 56, longestWordWidth: 0, maxWidth: 320),
        56,
      );
    });
  });
}
