import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _nothing(BuildContext context, PaywallIntroScope scope) =>
    const SizedBox.shrink();

void main() {
  group('the registry', () {
    test('no intro has no line and always counts as built', () {
      expect(paywallIntroBuilders.containsKey(PaywallIntroId.none), isFalse);
      expect(paywallIntroIsBuilt(PaywallIntroId.none), isTrue);
    });

    test('the false alarm is registered', () {
      expect(paywallIntroIsBuilt(PaywallIntroId.falseAlarm), isTrue);
    });

    test('every intro is short, and hands over before it ends', () {
      for (final MapEntry(key: id, value: intro)
          in paywallIntroBuilders.entries) {
        expect(intro.isSound, isTrue, reason: id.key);
        expect(intro.seconds, inInclusiveRange(1, 3), reason: id.key);
        expect(intro.skipTo, lessThanOrEqualTo(intro.handover), reason: id.key);
        expect(intro.handover, lessThan(intro.seconds), reason: id.key);
      }
    });
  });

  group('the contract', () {
    test('a tap skips to the way out and does nothing after it', () {
      const intro = PaywallIntro(
        seconds: 2,
        handover: 1.6,
        skipTo: 1.2,
        builder: _nothing,
      );
      expect(paywallIntroSkip(intro, 0), 1.2);
      expect(paywallIntroSkip(intro, 1.19), 1.2);
      expect(paywallIntroSkip(intro, 1.2), 1.2);
      expect(paywallIntroSkip(intro, 1.7), 1.7);
    });

    test('with no skip second a tap goes to the hand over', () {
      const intro = PaywallIntro(seconds: 2, handover: 1.6, builder: _nothing);
      expect(intro.skipTo, 1.6);
      expect(intro.isSound, isTrue);
    });

    test('times out of order, or too long, are not sound', () {
      const late = PaywallIntro(
        seconds: 2,
        handover: 1.2,
        skipTo: 1.5,
        builder: _nothing,
      );
      const noWayOut = PaywallIntro(
        seconds: 1.5,
        handover: 1.5,
        builder: _nothing,
      );
      const long = PaywallIntro(seconds: 4, handover: 3, builder: _nothing);
      expect(late.isSound, isFalse);
      expect(noWayOut.isSound, isFalse);
      expect(long.isSound, isFalse);
    });
  });
}
