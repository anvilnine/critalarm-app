import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse reads the three keys and treats anything else as none', () {
    expect(
      PaywallHeadlineVariant.parse('leaving'),
      PaywallHeadlineVariant.leaving,
    );
    expect(PaywallHeadlineVariant.parse('ended'), PaywallHeadlineVariant.ended);
    expect(PaywallHeadlineVariant.parse('none'), PaywallHeadlineVariant.none);
    for (final junk in [null, '', 'Leaving', 'sad', ' ended']) {
      expect(
        PaywallHeadlineVariant.parse(junk),
        PaywallHeadlineVariant.none,
        reason: '$junk',
      );
    }
  });

  test('the keys are fixed, they go in the location', () {
    expect(
      [for (final v in PaywallHeadlineVariant.values) v.key],
      ['none', 'leaving', 'ended'],
    );
  });
}
