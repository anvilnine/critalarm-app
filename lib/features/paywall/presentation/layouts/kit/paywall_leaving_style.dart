import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// The buy block of a layout, with the leaving words when the route is the
/// leaving one: the button "Keep Hosted" and the line that critical topics
/// already on keep ringing. Any other route gets the plain style.
PaywallBuyBlockStyle leavingBuyStyle(
  BuildContext context, {
  PaywallTone tone = PaywallTone.canvas,
}) {
  if (PaywallRouteInfo.headlineOf(context) != PaywallHeadlineVariant.leaving) {
    return PaywallBuyBlockStyle(tone: tone);
  }
  return PaywallBuyBlockStyle(
    tone: tone,
    buttonLabel: LocaleKeys.paywall_leaving_button.tr(
      namedArgs: {'name': paywallProductName(PaywallProduct.hosted)},
    ),
    note: LocaleKeys.paywall_leaving_note.tr(),
  );
}
