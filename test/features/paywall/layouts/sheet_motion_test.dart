import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SheetMotion at rest', () {
    const rest = SheetMotion.restAt;

    test('the entrance is over', () {
      expect(SheetMotion.scrim(rest), 1);
      expect(SheetMotion.rise(rest), 1);
      expect(SheetMotion.handle(rest), 1);
      expect(SheetMotion.peek(rest), 1);
      expect(rest, greaterThan(SheetMotion.buyBlockAt));
    });

    test('the row behind still shows the limit', () {
      expect(SheetMotion.limitLifted(rest), isFalse);
    });

    test('the badge is upright', () {
      expect(SheetMotion.lockedShake(rest), 0);
    });
  });

  group('SheetMotion entrance', () {
    test('everything starts hidden', () {
      expect(SheetMotion.scrim(0), 0);
      expect(SheetMotion.rise(0), 0);
      expect(SheetMotion.peek(0), 0);
      expect(SheetMotion.handle(0), closeTo(0.3, 1e-9));
    });

    test('the order is scrim, sheet, handle, face', () {
      // Half way up the rise the scrim is nearly down and the face has not
      // started.
      expect(SheetMotion.scrim(0.4), greaterThan(0.9));
      expect(SheetMotion.rise(0.4), inExclusiveRange(0, 1));
      expect(SheetMotion.peek(0.4), 0);
      // The handle starts before the face and the sheet lands before both
      // finish.
      expect(SheetMotion.handle(0.7), greaterThan(0.3));
      expect(SheetMotion.peek(0.7), 0);
      expect(SheetMotion.rise(0.82), 1);
      expect(SheetMotion.peek(1), inExclusiveRange(0, 1.2));
    });

    test('the rise passes its seat by only a little', () {
      var highest = 0.0;
      for (var t = 0.0; t <= 1; t += 0.005) {
        final r = SheetMotion.rise(t);
        if (r > highest) highest = r;
      }
      expect(highest, greaterThan(1));
      expect(highest, lessThan(1.08));
    });
  });

  group('SheetMotion loops', () {
    test('the limit lifts and comes back once a loop', () {
      expect(SheetMotion.limitLifted(2), isFalse);
      expect(SheetMotion.limitLifted(2.2), isTrue);
      expect(SheetMotion.limitLifted(8), isTrue);
      expect(SheetMotion.limitLifted(8.3), isFalse);
      // The next loop.
      expect(SheetMotion.limitLifted(SheetMotion.limitLoop + 1), isFalse);
      expect(SheetMotion.limitLifted(SheetMotion.limitLoop + 4), isTrue);
    });

    test('the badge shakes inside its window and nowhere else', () {
      expect(SheetMotion.lockedShake(1), 0);
      expect(SheetMotion.lockedShake(1.04), 0);
      expect(SheetMotion.lockedShake(1.1).abs(), greaterThan(0));
      expect(SheetMotion.lockedShake(1.48), 0);
      expect(SheetMotion.lockedShake(5), 0);
      expect(
        SheetMotion.lockedShake(SheetMotion.lockedLoop + 1.1).abs(),
        greaterThan(0),
      );
    });

    test('the shake never leaves its range and dies down', () {
      for (var t = 1.04; t <= 1.48; t += 0.002) {
        expect(SheetMotion.lockedShake(t).abs(), lessThanOrEqualTo(1));
      }
      expect(
        SheetMotion.lockedShake(1.45).abs(),
        lessThan(SheetMotion.lockedShake(1.1).abs()),
      );
    });
  });
}
