import 'package:critalarm/design/components/pass_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// A word that is [em] ems wide, as a width in points at a size.
double Function(double) _word(double em) =>
    (size) => em * size;

void main() {
  group('passFitValueSize', () {
    test('keeps the size when the word fits', () {
      expect(
        passFitValueSize(size: 42, available: 300, longestWord: _word(4)),
        42,
      );
    });

    test('steps down until the word fits', () {
      final fit = passFitValueSize(
        size: 42,
        available: 200,
        longestWord: _word(5),
      );
      expect(fit, lessThan(42));
      expect(fit * 5, lessThanOrEqualTo(200));
      expect(fit, greaterThan(38));
    });

    test('settles a scaler that is not linear', () {
      // A word whose width grows faster than its size.
      double word(double size) => size * size / 10;
      final fit = passFitValueSize(
        size: 42,
        available: 150,
        longestWord: word,
      );
      expect(word(fit), lessThanOrEqualTo(150));
    });

    test('stops at 30', () {
      final fit = passFitValueSize(
        size: 42,
        available: 100,
        longestWord: _word(6),
      );
      expect(fit, 30);
    });

    test('never grows a size that is already under the floor', () {
      expect(
        passFitValueSize(size: 28, available: 50, longestWord: _word(4)),
        28,
      );
    });

    test('ignores an empty value', () {
      expect(
        passFitValueSize(size: 42, available: 50, longestWord: (_) => 0),
        42,
      );
    });
  });
}
