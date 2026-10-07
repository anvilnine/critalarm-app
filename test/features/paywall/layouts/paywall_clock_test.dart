import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('phase', () {
    test('is 0 before the window, 1 after it, and linear inside', () {
      expect(phase(0, 1, 3), 0);
      expect(phase(1, 1, 3), 0);
      expect(phase(2, 1, 3), 0.5);
      expect(phase(3, 1, 3), 1);
      expect(phase(99, 1, 3), 1);
      expect(phase(-5, 1, 3), 0);
    });

    test('a window with no length steps at its start', () {
      expect(phase(0.99, 1, 1), 0);
      expect(phase(1, 1, 1), 1);
      expect(phase(2, 3, 1), 1);
      expect(phase(0, 3, 1), 0);
    });
  });

  group('loopT', () {
    test('wraps at the period', () {
      expect(loopT(0, 4), 0);
      expect(loopT(3, 4), 3);
      expect(loopT(4, 4), 0);
      expect(loopT(9.5, 4), 1.5);
    });

    test('a time before zero still lands inside the loop', () {
      expect(loopT(-1, 4), 3);
    });

    test('a period of zero or less answers 0', () {
      expect(loopT(7, 0), 0);
      expect(loopT(7, -2), 0);
    });
  });

  group('stagger', () {
    test('each item starts one step after the one before', () {
      expect(stagger(0, 1, each: 0.25), 1);
      expect(stagger(1, 1, each: 0.25), 0.75);
      expect(stagger(2, 1, each: 0.25), 0.5);
    });

    test('an item that has not started reads 0', () {
      expect(stagger(8, 1, each: 0.25), 0);
      expect(stagger(0, 0.2, start: 0.5), 0);
    });

    test('start moves the whole row', () {
      expect(stagger(0, 1, each: 0.25, start: 0.5), 0.5);
      expect(stagger(1, 1, each: 0.25, start: 0.5), 0.25);
    });

    test('feeds phase, so the first item finishes first', () {
      double p(int i, double t) => phase(stagger(i, t, each: 0.5), 0, 1);
      expect(p(0, 1), 1);
      expect(p(1, 1), 0.5);
      expect(p(2, 1), 0);
      expect(p(2, 2), 1);
    });
  });
}
