import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

class _Clock extends ChangeNotifier implements PaywallClock {
  @override
  double get value => 0;

  @override
  bool get isStill => true;

  @override
  void restart() {}
}

const _phones = <(Size, EdgeInsets)>[
  (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
  (Size(375, 667), EdgeInsets.only(top: 20)),
];

PaywallThanksScope _scope(
  Size size,
  EdgeInsets padding,
  PaywallProduct product, {
  Rect? mascot,
  double textScale = 1,
}) => PaywallThanksScope(
  clock: _Clock(),
  size: size,
  padding: padding,
  product: product,
  benefits: paywallBenefitsFor(product),
  mascot: mascot,
  textScale: textScale,
);

void main() {
  group('every version', () {
    test('has a pick up second and says where its mascot is', () {
      expect(paywallThanksBuilders, hasLength(6));
      for (final entry in paywallThanksBuilders.entries) {
        expect(entry.value.mascotAt, isNotNull, reason: entry.key.name);
        expect(entry.value.pickUp, greaterThan(0), reason: entry.key.name);
        expect(
          entry.value.pickUp,
          lessThan(entry.value.seconds),
          reason: entry.key.name,
        );
      }
    });

    test('is picked up at 0.5 seconds, and Confetti at 0.3', () {
      for (final entry in paywallThanksBuilders.entries) {
        expect(
          entry.value.pickUp,
          entry.key.key == 'confetti' ? 0.3 : 0.5,
          reason: entry.key.name,
        );
      }
    });

    test('has its mascot on screen and at least 90 wide at the pick up', () {
      for (final entry in paywallThanksBuilders.entries) {
        for (final (size, padding) in _phones) {
          for (final product in PaywallProduct.values) {
            for (final textScale in [1.0, 1.3]) {
              final scope = _scope(
                size,
                padding,
                product,
                textScale: textScale,
              );
              final box = entry.value.mascotAt!(scope, entry.value.pickUp);
              final reason =
                  '${entry.key.name} $size ${product.key} '
                  'x$textScale $box';
              expect(
                Offset.zero & size,
                predicate<Rect>(
                  (screen) =>
                      screen.contains(box.topLeft) &&
                      screen.contains(box.bottomRight),
                  'holds the mascot',
                ),
                reason: reason,
              );
              expect(box.width, greaterThanOrEqualTo(90), reason: reason);
            }
          }
        }
      }
    });

    test('keeps its mascot inside the screen at every 0.05 s of its show', () {
      for (final entry in paywallThanksBuilders.entries) {
        final thanks = entry.value;
        for (final (size, padding) in _phones) {
          final scope = _scope(size, padding, PaywallProduct.hosted);
          for (var t = thanks.pickUp; t <= thanks.seconds + 1; t += 0.05) {
            final box = thanks.mascotAt!(scope, t);
            expect(box.isFinite, isTrue, reason: '${entry.key.name} $t');
            expect(box.width, greaterThan(0), reason: '${entry.key.name} $t');
            expect(box.left, greaterThanOrEqualTo(-1), reason: '$t');
            expect(box.right, lessThanOrEqualTo(size.width + 1), reason: '$t');
            expect(box.bottom, lessThanOrEqualTo(size.height), reason: '$t');
          }
        }
      }
    });

    test('is at its stage at rest, whatever mascot the layout had', () {
      for (final entry in paywallThanksBuilders.entries) {
        final thanks = entry.value;
        for (final (size, padding) in _phones) {
          final bare = _scope(size, padding, PaywallProduct.pro);
          final withMascot = _scope(
            size,
            padding,
            PaywallProduct.pro,
            mascot: const Rect.fromLTWH(60, 500, 120, 120),
          );
          expect(
            thanks.mascotAt!(withMascot, thanks.seconds),
            thanks.mascotAt!(bare, thanks.seconds),
            reason: entry.key.name,
          );
        }
      }
    });

    test(
      'starts from the layout mascot, and from the stage after an outro',
      () {
        const layoutMascot = Rect.fromLTWH(60, 500, 120, 120);
        for (final entry in paywallThanksBuilders.entries) {
          final thanks = entry.value;
          final (size, padding) = _phones.first;
          final from = thanks.mascotAt!(
            _scope(size, padding, PaywallProduct.hosted, mascot: layoutMascot),
            0,
          );
          final stage = thanks.mascotAt!(
            _scope(size, padding, PaywallProduct.hosted),
            0,
          );
          // At second zero it stands over the layout's mascot, a little larger.
          expect(
            from.width,
            closeTo(layoutMascot.width * 1.04, 12),
            reason: entry.key.name,
          );
          expect(stage.width, greaterThanOrEqualTo(90), reason: entry.key.name);
        }
      },
    );
  });
}
