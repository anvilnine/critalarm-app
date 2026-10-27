import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// The buy block of a layout, with the leaving words when the route is the
/// leaving one: the button "Keep Hosted" and no small print above the
/// renewal lines. Any other route gets the plain style.
PaywallBuyBlockStyle leavingBuyStyle(
  BuildContext context, {
  PaywallTone tone = PaywallTone.canvas,
}) {
  final isLeaving =
      PaywallRouteInfo.headlineOf(context) == PaywallHeadlineVariant.leaving;
  return leavingBuyStyleFor(
    isLeaving: isLeaving,
    tone: tone,
    keepLabel: isLeaving
        ? LocaleKeys.paywall_leaving_button.tr(
            namedArgs: {'name': paywallProductName(PaywallProduct.hosted)},
          )
        : null,
  );
}

/// [leavingBuyStyle] for a route that [isLeaving], with the button words
/// ([keepLabel]) already in hand.
///
/// The leaving layouts already say that critical topics keep ringing, so
/// the slot between the button and the renewal lines is left empty.
PaywallBuyBlockStyle leavingBuyStyleFor({
  required bool isLeaving,
  required PaywallTone tone,
  String? keepLabel,
}) {
  if (!isLeaving) return PaywallBuyBlockStyle(tone: tone);
  return PaywallBuyBlockStyle(
    tone: tone,
    buttonLabel: keepLabel,
    showsNote: false,
  );
}
