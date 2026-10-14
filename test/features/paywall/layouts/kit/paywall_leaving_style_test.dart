import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_leaving_style.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the leaving buy block has no small print under the button', () {
    final style = leavingBuyStyleFor(
      isLeaving: true,
      tone: PaywallTone.canvas,
      keepLabel: 'Keep Cloud',
    );
    expect(style.buttonLabel, 'Keep Cloud');
    expect(style.showsNote, isFalse);
    expect(style.note, isNull);
  });

  test('any other route keeps the buy block as it was', () {
    final style = leavingBuyStyleFor(
      isLeaving: false,
      tone: PaywallTone.panel,
      keepLabel: 'Keep Cloud',
    );
    expect(style.tone, PaywallTone.panel);
    expect(style.buttonLabel, isNull);
    expect(style.showsNote, isTrue);
    expect(style.note, isNull);
    // The plain style and a style nobody asked about are the same.
    expect(const PaywallBuyBlockStyle().showsNote, isTrue);
  });
}
