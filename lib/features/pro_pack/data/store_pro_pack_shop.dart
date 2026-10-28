import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';

/// The identifier of the store offering that holds Pro. What is inside it is
/// set in the store dashboards and read as it comes.
const proPackOfferingId = 'pro';

/// [ProPackShop] over this build's [StoreBilling]. It reads one offering by
/// id and shows the store's own title and price strings for each entry in
/// it.
final class StoreProPackShop implements ProPackShop {
  StoreProPackShop(this._billing);

  final StoreBilling _billing;

  /// The entries behind the offers last read, by their handle.
  final Map<String, StoreCatalogEntry> _entries = {};

  @override
  Future<List<ProPackOffer>> readOffers() async {
    _entries.clear();
    if (!_billing.isConfigured) return const [];
    try {
      final offerings = await _billing.readOfferings();
      final offering = offerings.all[proPackOfferingId];
      if (offering == null) return const [];
      final offers = <ProPackOffer>[];
      for (final entry in offering.entries) {
        _entries[entry.id] = entry;
        offers.add(
          ProPackOffer(
            handle: entry.id,
            title: entry.title,
            price: entry.priceString,
          ),
        );
      }
      return offers;
    } on Object catch (_) {
      // A store that cannot be asked offers nothing to tap.
      _entries.clear();
      return const [];
    }
  }

  @override
  Future<ProPackStoreResult> buy(ProPackOffer offer) async {
    final entry = _entries[offer.handle];
    if (entry == null) return ProPackStoreResult.problem;
    try {
      await _billing.purchase(entry);
      return ProPackStoreResult.done;
    } on StoreBillingException catch (error) {
      return switch (error.error) {
        StoreBillingError.cancelled => ProPackStoreResult.cancelled,
        // Ask to Buy, or a Play payment that has not cleared. The store
        // took it, so the buyer must not be told it failed.
        StoreBillingError.pending => ProPackStoreResult.pending,
        _ => ProPackStoreResult.problem,
      };
    } on Object catch (_) {
      return ProPackStoreResult.problem;
    }
  }

  @override
  Future<ProPackStoreResult> restore() async {
    if (!_billing.isConfigured) return ProPackStoreResult.problem;
    try {
      await _billing.restore();
      return ProPackStoreResult.done;
    } on Object catch (_) {
      return ProPackStoreResult.problem;
    }
  }
}
