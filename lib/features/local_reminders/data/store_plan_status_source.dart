import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/core/store/services/store_customer.dart';
import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/plan_status_source.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';

/// Reads idea 8's three facts off what the store knows about the account: a
/// billing issue, a yearly renewal coming up, and a plan that will not
/// renew.
final class StorePlanStatusSource implements PlanStatusSource {
  StorePlanStatusSource(this._subscriptions);

  final SubscriptionRepository _subscriptions;

  @override
  Future<PlanStatus?> read(DeviceTimeZone timeZone) async {
    final info = (await _subscriptions.getCustomerInfo()).getOrNull();
    if (info == null) return null;
    final offerings = (await _subscriptions.getOfferings()).getOrNull();
    return planStatusFrom(
      info,
      pricesByProduct: {
        for (final offering in offerings?.all.values ?? const <StoreOffering>[])
          for (final entry in offering.entries)
            entry.productId: entry.priceString,
      },
      timeZone: timeZone,
    );
  }

  /// [pricesByProduct] maps a store product id to its price. The renewal
  /// price is the one of the product the user owns; with no match it stays
  /// null and the renewal notice is not sent, rather than quoting another
  /// product's price.
  static PlanStatus? planStatusFrom(
    StoreCustomer info, {
    required Map<String, String> pricesByProduct,
    required DeviceTimeZone timeZone,
  }) {
    // Not a gate: this reads when the plan renews or ends, for the wording
    // of the "plan is ending" notice.
    final active = info.entitlements.active; // access-ok: reads end dates
    final pro = active[SubscriptionTier.proEntitlement];
    if (pro == null) return null;
    final product = pro.productId.toLowerCase();
    // App Store products carry the period in the id (`...annual`); Play
    // products carry it in the base plan id (`yearly`).
    final isYearly =
        pro.productPlanId == 'yearly' ||
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
      expiresAtInstant: DateTime.tryParse(pro.expirationDate ?? '')?.toUtc(),
      billingIssueAt: wall(pro.billingIssueDetectedAt),
      priceString: isYearly ? _priceOf(pro, pricesByProduct) : null,
      managementUrl: info.managementUrl,
    );
  }

  /// App Store ids match as they are. A Play subscription's store product
  /// id is `<product>:<base plan>`.
  static String? _priceOf(StoreEntitlement pro, Map<String, String> prices) {
    final exact = prices[pro.productId];
    if (exact != null) return exact;
    final plan = pro.productPlanId;
    return plan == null ? null : prices['${pro.productId}:$plan'];
  }
}
