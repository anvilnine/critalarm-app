import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppScreenScaffold.topBackingAmount', () {
    test('shows nothing at rest', () {
      expect(AppScreenScaffold.topBackingAmount(0), 0);
    });

    test('shows nothing while the list is pulled down past its start', () {
      expect(AppScreenScaffold.topBackingAmount(-40), 0);
    });

    test('comes in over the first 16 of scroll and then stays', () {
      expect(AppScreenScaffold.topBackingAmount(8), 0.5);
      expect(AppScreenScaffold.topBackingAmount(16), 1);
      expect(AppScreenScaffold.topBackingAmount(900), 1);
    });
  });

  group('AppScreenScaffold.bottomBackingAmount', () {
    double amount(double extentAfter, {double? clearance}) =>
        AppScreenScaffold.bottomBackingAmount(
          extentAfter: extentAfter,
          clearance: clearance ?? AppScreenScaffold.listBarClearance,
        );

    test('shows nothing on a screen that does not scroll', () {
      expect(amount(0), 0);
    });

    test('shows nothing while the last row is still clear of the bar', () {
      // The list leaves 16 above the bar at its end, so with up to 16 left
      // to scroll the last row has not reached the bar yet.
      expect(amount(3), 0);
      expect(amount(16), 0);
    });

    test('comes in as a row runs under the bar', () {
      expect(amount(20), 0.5);
      expect(amount(24), 1);
      expect(amount(400), 1);
    });

    test('a body that leaves the room itself keeps 12 clear', () {
      const clearance = AppScreenScaffold.bodyBarClearance;
      expect(clearance, 12);
      expect(amount(12, clearance: clearance), 0);
      expect(amount(16, clearance: clearance), 0.5);
      expect(amount(20, clearance: clearance), 1);
    });

    test('shows nothing when the list is pushed past its end', () {
      expect(amount(-30), 0);
    });
  });
}
