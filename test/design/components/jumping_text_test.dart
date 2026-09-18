import 'package:critalarm/design/components/jumping_text.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const half = Duration(milliseconds: 180);

  group('letterHop', () {
    test('a letter sits on the line before and after its hop', () {
      expect(letterHop(Duration.zero, 0), 0);
      expect(letterHop(letterHopDuration, 0), 0);
      expect(letterHop(letterHopDuration * 2, 0), 0);
    });

    test('a letter is at the top halfway through its hop', () {
      expect(letterHop(half, 0), closeTo(1, 0.0001));
    });

    test('each letter starts one stagger after the one before', () {
      expect(letterHop(half, 3), lessThan(1));
      expect(letterHop(half + letterHopStagger * 3, 3), closeTo(1, 0.0001));
    });
  });

  group('letterLeave', () {
    test('a letter is in place before it starts leaving', () {
      expect(letterLeave(Duration.zero, 0), 0);
      expect(letterLeave(letterHopStagger * 2, 3), 0);
    });

    test('halfway through its leave it is half gone', () {
      expect(letterLeave(half, 0), closeTo(0.5, 0.0001));
    });

    test('after its leave it stays gone', () {
      expect(letterLeave(letterHopDuration * 3, 0), 1);
    });
  });

  group('gradientAt', () {
    const red = Color(0xFFFF0000);
    const green = Color(0xFF00FF00);
    const blue = Color(0xFF0000FF);

    test('ends are the first and last stop', () {
      expect(gradientAt([red, green, blue], 0), red);
      expect(gradientAt([red, green, blue], 1), blue);
    });

    test('the middle of three stops is the middle colour', () {
      expect(gradientAt([red, green, blue], 0.5), green);
    });

    test('one stop is that colour everywhere', () {
      expect(gradientAt([red], 0.7), red);
    });
  });
}
