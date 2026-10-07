import 'package:flutter/foundation.dart';

/// One thing the store offers for Pro, with the store's own words.
///
/// [title] and [price] are shown as they come. The app never builds, parses
/// or compares either one.
@immutable
final class ProPackOffer {
  const ProPackOffer({
    required this.handle,
    required this.title,
    required this.price,
  });

  /// What the shop hands back to buy this offer. Opaque to everything else.
  final String handle;
  final String title;
  final String price;

  @override
  bool operator ==(Object other) =>
      other is ProPackOffer &&
      other.handle == handle &&
      other.title == title &&
      other.price == price;

  @override
  int get hashCode => Object.hash(handle, title, price);
}

/// How one trip to the store ended, as far as the store itself goes. Whether
/// the account now holds the pack is the relay's answer, not this one.
enum ProPackStoreResult {
  /// The store finished the purchase or the restore.
  done,

  /// The person backed out.
  cancelled,

  /// The store took the purchase and is holding the payment: it waits for
  /// an approval or for the money. Nothing failed and nothing is held yet.
  pending,

  /// The store reported a problem of its own.
  problem,
}

/// Where Pro is bought. The sheet lists what it offers and nothing else.
abstract interface class ProPackShop {
  /// What is on sale now. Empty when Pro is not on sale, when the store
  /// cannot be asked, and in a build that skips the store.
  Future<List<ProPackOffer>> readOffers();

  Future<ProPackStoreResult> buy(ProPackOffer offer);

  Future<ProPackStoreResult> restore();
}

/// The shop of a build that skips the store. Nothing is on sale.
final class ClosedProPackShop implements ProPackShop {
  const ClosedProPackShop();

  @override
  Future<List<ProPackOffer>> readOffers() async => const [];

  @override
  Future<ProPackStoreResult> buy(ProPackOffer offer) async =>
      ProPackStoreResult.problem;

  @override
  Future<ProPackStoreResult> restore() async => ProPackStoreResult.problem;
}
