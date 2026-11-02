import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:critalarm/features/paywall/domain/store_catalog.dart';

/// [StoreCatalog] over this build's [StoreBilling]. It finds each product
/// by the offering and entry ids in the price book.
final class BillingStoreCatalog implements StoreCatalog {
  BillingStoreCatalog(this._billing, this._book);

  final StoreBilling _billing;
  final PriceBook _book;

  /// The entries behind the plans last read, by plan.
  final Map<PriceBookPlan, StoreCatalogEntry> _entries = {};

  @override
  Future<List<StorePlan>> plansFor(PaywallProduct product) async {
    final plans = [
      for (final plan in PriceBookPlan.values)
        if (plan.product == product) plan,
    ];
    _entries.removeWhere((plan, _) => plan.product == product);
    if (!_billing.isConfigured) return const [];
    final StoreOfferings offerings;
    try {
      offerings = await _billing.readOfferings();
    } on Object catch (_) {
      return const [];
    }
    final found = <StorePlan>[];
    for (final plan in plans) {
      final price = _book.priceOf(plan);
      if (price == null) continue;
      final offering = price.offeringId == null
          ? offerings.current
          : offerings.all[price.offeringId];
      final entry = _entryIn(offering, price.packageId);
      if (entry == null) continue;
      _entries[plan] = entry;
      found.add(
        StorePlan(
          id: plan,
          product: product,
          kind: switch (plan) {
            PriceBookPlan.hostedYearly => StorePlanKind.yearly,
            PriceBookPlan.hostedMonthly => StorePlanKind.monthly,
            PriceBookPlan.proOnce => StorePlanKind.oneTime,
          },
          priceString: entry.priceString,
          price: entry.price,
          currency: entry.currency,
          pricePerMonthString: entry.pricePerMonthString,
        ),
      );
    }
    return found;
  }

  /// The entry named [entryId] in [offering], or the offering's only entry
  /// when no id is named.
  static StoreCatalogEntry? _entryIn(StoreOffering? offering, String? entryId) {
    if (offering == null) return null;
    final entries = offering.entries;
    if (entryId == null) return entries.length == 1 ? entries.single : null;
    for (final entry in entries) {
      if (entry.id == entryId) return entry;
    }
    return null;
  }

  @override
  Future<StoreOutcome> buy(StorePlan plan) async {
    final entry = _entries[plan.id];
    if (entry == null) return StoreOutcome.problem;
    try {
      await _billing.purchase(entry);
      return StoreOutcome.done;
    } on StoreBillingException catch (error) {
      return error.error == StoreBillingError.cancelled
          ? StoreOutcome.cancelled
          : StoreOutcome.problem;
    } on Object catch (_) {
      return StoreOutcome.problem;
    }
  }

  @override
  Future<StoreOutcome> restore() async {
    if (!_billing.isConfigured) return StoreOutcome.problem;
    try {
      await _billing.restore();
      return StoreOutcome.done;
    } on Object catch (_) {
      return StoreOutcome.problem;
    }
  }
}
