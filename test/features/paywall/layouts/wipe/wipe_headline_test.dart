import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wipeHeadlineFor', () {
    test('an ended Hosted plan has its own headline', () {
      expect(
        wipeHeadlineFor(
          isHosted: true,
          variant: PaywallHeadlineVariant.ended,
        ),
        WipeHeadline.ended,
      );
    });

    test('no variant keeps the headline each product has today', () {
      expect(
        wipeHeadlineFor(isHosted: true, variant: PaywallHeadlineVariant.none),
        WipeHeadline.hosted,
      );
      expect(
        wipeHeadlineFor(isHosted: false, variant: PaywallHeadlineVariant.none),
        WipeHeadline.pro,
      );
    });

    test('Pro never has an ended headline: no Pro plan ends this way', () {
      expect(
        wipeHeadlineFor(isHosted: false, variant: PaywallHeadlineVariant.ended),
        WipeHeadline.pro,
      );
    });

    test('the leaving variant reads as the plain headline until Part 2', () {
      expect(
        wipeHeadlineFor(
          isHosted: true,
          variant: PaywallHeadlineVariant.leaving,
        ),
        WipeHeadline.hosted,
      );
    });
  });
}
