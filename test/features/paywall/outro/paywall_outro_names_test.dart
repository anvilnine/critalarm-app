import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every outro has its own name key', () {
    final keys = {
      for (final outro in PaywallOutroId.values) paywallOutroNameKey(outro),
    };
    expect(keys.length, PaywallOutroId.values.length);
    for (final key in keys) {
      expect(key, startsWith('paywall_outro.names.'));
    }
  });

  test('the name is a string for every outro', () {
    for (final outro in PaywallOutroId.values) {
      expect(paywallOutroName(outro), isNotEmpty);
    }
  });
}
