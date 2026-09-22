import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:critalarm/features/reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/reminders/domain/plan_status_source.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Reads idea 8's three facts off RevenueCat's `CustomerInfo`: a billing
/// issue, a yearly renewal coming up, and a plan that will not renew.
final class RevenueCatPlanStatusSource implements PlanStatusSource {
  RevenueCatPlanStatusSource(this._subscriptions);

  final SubscriptionRepository _subscriptions;

  @override
  Future<PlanStatus?> read(DeviceTimeZone timeZone) async {
    final info = (await _subscriptions.getCustomerInfo()).getOrNull();
    if (info == null) return null;
    final offerings = (await _subscriptions.getOfferings()).getOrNull();
    return planStatusFrom(
      info,
      pricesByProduct: {
        for (final offering in offerings?.all.values ?? const <Offering>[])
          for (final package in offering.availablePackages)
            package.storeProduct.identifier: package.storeProduct.priceString,
      },
      timeZone: timeZone,
    );
  }

  /// [pricesByProduct] maps a store product id to its price. The renewal
  /// price is the one of the product the user owns; with no match it stays
  /// null and the renewal notice is not sent, rather than quoting another
  /// product's price.
  static PlanStatus? planStatusFrom(
    CustomerInfo info, {
    required Map<String, String> pricesByProduct,
    required DeviceTimeZone timeZone,
  }) {
    final pro = info.entitlements.active[SubscriptionTier.proEntitlement];
    if (pro == null) return null;
    final product = pro.productIdentifier.toLowerCase();
    // App Store products carry the period in the id (`...annual`); Play
    // products carry it in the base plan id (`yearly`).
    final isYearly =
        pro.productPlanIdentifier == 'yearly' ||
        product.contains('annual') ||
        product.contains('yearly');

    DateTime? wall(String? iso) {
      final at = iso == null ? null : DateTime.tryParse(iso);
      return at == null ? null : timeZone.toWall(at);
    }

    return PlanStatus(
      isActive: pro.isActive,
      isYearly: isYearly,
      willRenew: pro.willRenew,
      expiresAt: wall(pro.expirationDate),
      billingIssueAt: wall(pro.billingIssueDetectedAt),
      priceString: isYearly ? _priceOf(pro, pricesByProduct) : null,
      managementUrl: info.managementURL,
    );
  }

  /// App Store ids match as they are. A Play subscription's store product
  /// id is `<product>:<base plan>`.
  static String? _priceOf(EntitlementInfo pro, Map<String, String> prices) {
    final exact = prices[pro.productIdentifier];
    if (exact != null) return exact;
    final plan = pro.productPlanIdentifier;
    return plan == null ? null : prices['${pro.productIdentifier}:$plan'];
  }
}
