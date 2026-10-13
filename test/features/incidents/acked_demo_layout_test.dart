import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ackedDemoRippleHeightFor', () {
    double ripple(double room, double copy, {double gap = 20}) =>
        ackedDemoRippleHeightFor(room: room, copyHeight: copy, gap: gap);

    test('is what the words and the gap leave', () {
      expect(ripple(500, 300), 180);
      expect(ripple(500, 100, gap: 24), 376);
    });

    test('is nothing when the words take the room', () {
      // Words that fit with no more than the gap to spare.
      expect(ripple(320, 300), 0);
      expect(ripple(310, 300), 0);
      // Words taller than the room are held to it and scroll.
      expect(ripple(300, 300), 0);
    });

    test('is never negative', () {
      expect(ripple(0, 0), 0);
      expect(ripple(-40, 0), 0);
    });
  });
}
