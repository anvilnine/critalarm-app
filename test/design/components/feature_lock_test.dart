import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/design/components/feature_lock.dart';
import 'package:critalarm/design/components/pro_badge.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const locked = FeatureLocked(Holding.pro);
  const childKey = ValueKey('child');

  Widget wrap(Widget child, {double textScale = 1}) => MaterialApp(
    theme: buildLightTheme(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  Widget lockedBox({
    FeatureLockSeat seat = FeatureLockSeat.above,
    bool drawsBadge = true,
    VoidCallback? onLockedTap,
  }) => FeatureLock(
    decision: locked,
    planWord: 'Pro',
    lockedWord: 'locked',
    badgeSeat: seat,
    drawsBadge: drawsBadge,
    onLockedTap: onLockedTap,
    child: const SizedBox(key: childKey, width: 120, height: 48),
  );

  group('a badge seated above', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('covers no more than the tuck at text size $scale', (
        tester,
      ) async {
        await tester.pumpWidget(wrap(lockedBox(), textScale: scale));
        final child = tester.getRect(find.byKey(childKey));
        final badge = tester.getRect(find.byType(ProBadge));

        expect(
          badge.bottom,
          moreOrLessEquals(child.top + FeatureLock.badgeTuck),
        );
        // It fits the room a caller is told to leave over the child.
        expect(
          child.top - badge.top,
          lessThanOrEqualTo(FeatureLock.badgeRoomAbove),
        );
      });
    }

    testWidgets('sits on the corner when asked to, as before', (tester) async {
      await tester.pumpWidget(wrap(lockedBox(seat: FeatureLockSeat.corner)));
      final child = tester.getRect(find.byKey(childKey));
      final badge = tester.getRect(find.byType(ProBadge));

      expect(badge.top, moreOrLessEquals(child.top - 6));
      expect(badge.right, moreOrLessEquals(child.right + 6));
    });
  });

  testWidgets('a lock that draws no badge still takes the tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(lockedBox(drawsBadge: false, onLockedTap: () => taps++)),
    );

    expect(find.byType(ProBadge), findsNothing);
    await tester.tap(find.byType(FeatureLock));
    expect(taps, 1);
  });

  testWidgets('no badge once the feature is open', (tester) async {
    await tester.pumpWidget(
      wrap(
        const FeatureLock(
          decision: FeatureOpen(),
          planWord: 'Pro',
          lockedWord: 'locked',
          badgeSeat: FeatureLockSeat.above,
          child: SizedBox(key: childKey, width: 120, height: 48),
        ),
      ),
    );
    expect(find.byType(ProBadge), findsNothing);
  });
}
