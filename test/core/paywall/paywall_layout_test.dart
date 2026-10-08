import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every layout has the key it ships under', () {
    expect(
      {for (final l in PaywallLayoutId.values) l.name: l.key},
      {
        'hero': 'hero',
        'sheet': 'sheet',
        'proof': 'proof',
        'bento': 'bento',
        'reel': 'reel',
        'falseAlarm': 'false_alarm',
        'stage': 'stage',
        'sentence': 'sentence',
        'wipe': 'wipe',
        'doors': 'doors',
        'receipt': 'receipt',
        'plain': 'plain',
      },
    );
  });

  test('hero is listed first, so the developer page opens on it', () {
    expect(PaywallLayoutId.values.first, PaywallLayoutId.hero);
  });

  test('fromKey finds each layout by its key', () {
    for (final layout in PaywallLayoutId.values) {
      expect(PaywallLayoutId.fromKey(layout.key), layout);
    }
  });

  test('fromKey answers null for a missing or unknown key', () {
    expect(PaywallLayoutId.fromKey(null), isNull);
    expect(PaywallLayoutId.fromKey(''), isNull);
    expect(PaywallLayoutId.fromKey('falseAlarm'), isNull);
    expect(PaywallLayoutId.fromKey('ledger'), isNull);
  });

  test('the path of a layout sits under /plans', () {
    expect(paywallLayoutPathFor('false_alarm'), '/plans/false_alarm');
  });

  test('the silent cues take every call and do nothing', () {
    const SilentPaywallCues()
      ..open()
      ..gag()
      ..print()
      ..tick()
      ..pickPlan(yearly: true)
      ..pickPlan(yearly: false)
      ..bought()
      ..close();
  });
}
