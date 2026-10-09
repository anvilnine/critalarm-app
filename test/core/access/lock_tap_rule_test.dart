import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:flutter_test/flutter_test.dart';

LockTapAnswer _ask(
  FeatureDecision decision,
  LockTapKind tap, {
  bool isPlanRead = true,
  bool hasTry = false,
}) => lockTapFor(
  decision: decision,
  isPlanRead: isPlanRead,
  hasTry: hasTry,
  tap: tap,
);

const _open = FeatureDecision.open();
const _lockedHosted = FeatureDecision.locked(Holding.hosted);
const _lockedPro = FeatureDecision.locked(Holding.pro);
const _confirming = FeatureDecision.confirming(Holding.pro);
const _unread = FeatureDecision.unread(Holding.hosted);
const _notOffered = FeatureDecision.notOffered();

const _decisions = <String, FeatureDecision>{
  'open': _open,
  'locked with Hosted': _lockedHosted,
  'locked with Pro': _lockedPro,
  'confirming': _confirming,
  'unread': _unread,
  'not offered': _notOffered,
};

void main() {
  group('row 1: open always opens the page', () {
    for (final entry in _decisions.entries) {
      for (final isPlanRead in [true, false]) {
        for (final hasTry in [true, false]) {
          test(
            '${entry.key}, plan read $isPlanRead, try $hasTry',
            () => expect(
              _ask(
                entry.value,
                LockTapKind.open,
                isPlanRead: isPlanRead,
                hasTry: hasTry,
              ),
              const OpenPage(),
            ),
          );
        }
      }
    }
  });

  group('row 2: not offered is nothing', () {
    for (final tap in LockTapKind.values.where((k) => k != LockTapKind.open)) {
      for (final isPlanRead in [true, false]) {
        for (final hasTry in [true, false]) {
          test('${tap.name}, plan read $isPlanRead, try $hasTry', () {
            expect(
              _ask(
                _notOffered,
                tap,
                isPlanRead: isPlanRead,
                hasTry: hasTry,
              ),
              const Nothing(),
            );
          });
        }
      }
    }
  });

  group('row 3: an unread plan waits', () {
    for (final entry in _decisions.entries) {
      if (entry.value is FeatureNotOffered) continue;
      for (final tap in [
        LockTapKind.tryIt,
        LockTapKind.keep,
        LockTapKind.seePlan,
      ]) {
        for (final hasTry in [true, false]) {
          test('${entry.key}, ${tap.name}, try $hasTry', () {
            expect(
              _ask(entry.value, tap, isPlanRead: false, hasTry: hasTry),
              const WaitForPlan(),
            );
          });
        }
      }
    }
  });

  group('row 4: nothing locked, try and keep just do it', () {
    for (final decision in [_open, _confirming, _unread]) {
      for (final tap in [LockTapKind.tryIt, LockTapKind.keep]) {
        for (final hasTry in [true, false]) {
          test('$decision, ${tap.name}, try $hasTry', () {
            expect(_ask(decision, tap, hasTry: hasTry), const DoIt());
          });
        }
      }
    }
  });

  group('row 5: nothing locked, a plan button does nothing', () {
    for (final decision in [_open, _confirming, _unread]) {
      for (final hasTry in [true, false]) {
        test('$decision, try $hasTry', () {
          expect(
            _ask(decision, LockTapKind.seePlan, hasTry: hasTry),
            const Nothing(),
          );
        });
      }
    }
  });

  group('row 6: a locked try with a try is a try', () {
    for (final decision in [_lockedHosted, _lockedPro]) {
      test('$decision', () {
        expect(
          _ask(decision, LockTapKind.tryIt, hasTry: true),
          const TryIt(),
        );
      });
    }
  });

  group('row 7: a locked try without a try opens the paywall', () {
    test('Hosted', () {
      expect(
        _ask(_lockedHosted, LockTapKind.tryIt),
        const OpenPaywall(Holding.hosted),
      );
    });
    test('Pro', () {
      expect(
        _ask(_lockedPro, LockTapKind.tryIt),
        const OpenPaywall(Holding.pro),
      );
    });
  });

  group('row 8: keep and a plan button open the paywall for the offer', () {
    for (final tap in [LockTapKind.keep, LockTapKind.seePlan]) {
      for (final hasTry in [true, false]) {
        test('${tap.name} with Hosted, try $hasTry', () {
          expect(
            _ask(_lockedHosted, tap, hasTry: hasTry),
            const OpenPaywall(Holding.hosted),
          );
        });
        test('${tap.name} with Pro, try $hasTry', () {
          expect(
            _ask(_lockedPro, tap, hasTry: hasTry),
            const OpenPaywall(Holding.pro),
          );
        });
      }
    }
  });

  test('only a locked decision on a read plan ever opens a paywall', () {
    for (final entry in _decisions.entries) {
      for (final tap in LockTapKind.values) {
        for (final isPlanRead in [true, false]) {
          for (final hasTry in [true, false]) {
            final answer = _ask(
              entry.value,
              tap,
              isPlanRead: isPlanRead,
              hasTry: hasTry,
            );
            final reason =
                '${entry.key}, ${tap.name}, read $isPlanRead, try $hasTry';
            if (answer is OpenPaywall) {
              expect(entry.value, isA<FeatureLocked>(), reason: reason);
              expect(isPlanRead, isTrue, reason: reason);
              expect(tap, isNot(LockTapKind.open), reason: reason);
              expect(answer.offer, (entry.value as FeatureLocked).offer);
            }
            if (answer is TryIt || answer is DoIt) {
              expect(isPlanRead, isTrue, reason: reason);
            }
          }
        }
      }
    }
  });
}
