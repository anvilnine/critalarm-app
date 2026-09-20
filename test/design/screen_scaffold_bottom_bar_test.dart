import 'package:critalarm/design/components/floating_tab_bar.dart';
import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';

/// A home indicator's worth of safe area, so the numbers below read like a
/// real phone rather than a bare 0.
const double safeArea = 34;

void main() {
  group('AppScreenScaffold.bottomBarInset', () {
    test('a screen with no tab bar keeps the safe area and the gap', () {
      expect(
        AppScreenScaffold.bottomBarInset(
          hasTabBar: false,
          isExpanded: false,
          safeAreaBottom: safeArea,
        ),
        safeArea + AppScreenScaffold.bottomBarGap,
      );
    });

    test('a tab bar lifts the slot clear of it', () {
      expect(
        AppScreenScaffold.bottomBarInset(
          hasTabBar: true,
          isExpanded: false,
          safeAreaBottom: safeArea,
        ),
        safeArea +
            AppScreenScaffold.bottomBarGap +
            AppFloatingTabBar.contentGap,
      );
    });

    test('the lift clears the top of the tab bar', () {
      final slotBottom = AppScreenScaffold.bottomBarInset(
        hasTabBar: true,
        isExpanded: false,
        safeAreaBottom: safeArea,
      );
      const barTop =
          safeArea + AppFloatingTabBar.edgeGap + AppFloatingTabBar.height;
      expect(slotBottom, greaterThan(barTop));
    });

    test('an expanded display leaves the slot where it is', () {
      expect(
        AppScreenScaffold.bottomBarInset(
          hasTabBar: true,
          isExpanded: true,
          safeAreaBottom: safeArea,
        ),
        safeArea + AppScreenScaffold.bottomBarGap,
      );
    });

    test('a display with no safe area still gets the gap', () {
      expect(
        AppScreenScaffold.bottomBarInset(
          hasTabBar: false,
          isExpanded: false,
          safeAreaBottom: 0,
        ),
        AppScreenScaffold.bottomBarGap,
      );
    });
  });
}
