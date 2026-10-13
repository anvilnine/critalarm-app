import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_registry.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_timeline.dart';
import 'package:critalarm/features/paywall/presentation/outros/cloud_climb/cloud_climb_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/confetti/confetti_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
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

PaywallThanksScope _scope(Size size, EdgeInsets padding, {double from = 0}) =>
    PaywallThanksScope(
      clock: _Clock(),
      size: size,
      padding: padding,
      product: PaywallProduct.pro,
      benefits: paywallBenefitsFor(PaywallProduct.pro),
      mascotFrom: from,
    );

void _expectClose(Rect a, Rect b, String reason) {
  expect(a.left, closeTo(b.left, 0.01), reason: reason);
  expect(a.top, closeTo(b.top, 0.01), reason: reason);
  expect(a.right, closeTo(b.right, 0.01), reason: reason);
  expect(a.bottom, closeTo(b.bottom, 0.01), reason: reason);
}

void main() {
  test('thanksCritSeen lifts and stretches about the bottom middle', () {
    const box = Rect.fromLTWH(100, 200, 100, 100);
    expect(thanksCritSeen(box, null), box);
    expect(thanksCritSeen(box, (lift: 0, stretch: 1)), box);
    final lifted = thanksCritSeen(box, (lift: 0.5, stretch: 1));
    expect(lifted, const Rect.fromLTWH(100, 150, 100, 100));
    final squashed = thanksCritSeen(box, (lift: 0, stretch: 0.8));
    expect(squashed.bottom, 300);
    expect(squashed.height, closeTo(80, 1e-9));
    expect(squashed.width, closeTo(112, 1e-9));
    expect(squashed.center.dx, 150);
  });

  test('Confetti is picked up where it does not lean, after either outro', () {
    final confetti = paywallThanksBuilders.entries
        .firstWhere((e) => e.key.key == 'confetti')
        .value;
    for (final outro in paywallOutroBuilders.values) {
      final from = paywallThanksMascotFrom(
        outro: outro,
        pickUp: confetti.pickUp,
      );
      expect(ConfettiTimeline.lean(from), closeTo(0, 1e-9));
    }
  });

  test(
    'the end state draws its mascot on the very first frame of the swap',
    () {
      for (final outro in paywallOutroBuilders.values) {
        for (final thanks in paywallThanksBuilders.values) {
          final from = paywallThanksMascotFrom(
            outro: outro,
            pickUp: thanks.pickUp,
          );
          final clock = paywallThanksSecondAfterOutro(
            outro.seconds,
            outro: outro,
            pickUp: thanks.pickUp,
          );
          expect(clock >= from, isTrue, reason: '$clock vs $from');
        }
      }
    },
  );

  group('the swap, for every outro and every end state', () {
    for (final outroEntry in paywallOutroBuilders.entries) {
      for (final thanksEntry in paywallThanksBuilders.entries) {
        final outro = outroEntry.value;
        final thanks = thanksEntry.value;
        final name = '${outroEntry.key.name} into ${thanksEntry.key.name}';
        for (final (size, padding) in _phones) {
          test(
            '$name on $size: the outro lands on what the end state draws',
            () {
              final from = paywallThanksMascotFrom(
                outro: outro,
                pickUp: thanks.pickUp,
              );
              final end = _scope(size, padding, from: from);
              final pose = thanks.mascotPoseAt!(end, from);
              final seen = thanksCritSeen(thanks.mascotAt!(end, from), pose);

              // What the end state draws at that second: its box, lifted and
              // stretched. The outro's last frame is the same rectangle.
              final outroBox = outroEntry.key.key == 'break_lift_ring'
                  ? BreakLiftRingTimeline.pose(
                      BreakLiftRingTimeline.end,
                      size: size,
                      land: seen,
                    ).box
                  : CloudClimbTimeline.critBox(
                      CloudClimbTimeline.end,
                      size: size,
                      land: seen,
                    );
              _expectClose(outroBox, seen, name);

              // Frames either side of the swap: only the end state's own pace.
              // Its jump starts fast, so one frame can move it a few points,
              // where before this the swap itself added a jump of dozens.
              const frame = 1 / 120;
              for (final dt in [-frame, frame]) {
                final near = thanksCritSeen(
                  thanks.mascotAt!(end, from + dt),
                  thanks.mascotPoseAt!(end, from + dt),
                );
                expect(
                  (near.center - seen.center).distance,
                  lessThan(16),
                  reason: '$name dt=$dt',
                );
                expect((near.height - seen.height).abs(), lessThan(16));
              }
            },
          );
        }
      }
    }
  });

  test('Confetti would jump at the swap without the pose', () {
    // The failing case this fixes: at the old pick up the mascot is high in
    // its jump, and its bare box is far from where it is drawn.
    const size = Size(390, 844);
    const padding = EdgeInsets.only(top: 47, bottom: 34);
    final thanks = paywallThanksBuilders.entries
        .firstWhere((e) => e.key.key == 'confetti')
        .value;
    final scope = _scope(size, padding, from: 0.5);
    final bare = thanks.mascotAt!(scope, 0.5);
    final seen = thanksCritSeen(bare, thanks.mascotPoseAt!(scope, 0.5));
    expect((seen.center - bare.center).distance, greaterThan(5));
  });
}
