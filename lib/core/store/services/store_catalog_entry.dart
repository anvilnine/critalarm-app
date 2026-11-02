import 'package:flutter/foundation.dart';

/// How long one purchase of a catalog entry lasts before the store bills
/// again.
enum StorePeriod {
  monthly,
  yearly,

  /// Bought once and kept: the Pro pack.
  lifetime,

  /// Any other length, or one the store did not name. A reader that needs a
  /// month or a year looks at the entry's id instead.
  other,
}

/// A price the store charges before the regular one: a free trial when
/// [price] is zero, an introductory price otherwise.
@immutable
final class StoreIntroOffer {
  const StoreIntroOffer({
    required this.priceString,
    required this.price,
    required this.period,
    required this.cycles,
  });

  /// The amount as the store words it, currency sign included.
  final String priceString;
  final double price;

  /// One billing period of the offer, in ISO 8601 (`P1W`, `P1M`).
  final String period;

  /// How many of those periods the offer lasts.
  final int cycles;

  @override
  bool operator ==(Object other) =>
      other is StoreIntroOffer &&
      other.priceString == priceString &&
      other.price == price &&
      other.period == period &&
      other.cycles == cycles;

  @override
  int get hashCode => Object.hash(priceString, price, period, cycles);
}

/// One thing a store has on sale, in no store's types.
///
/// A paywall reads these and hands one back to buy it. The store service
/// that made it knows which store object stands behind it.
@immutable
final class StoreCatalogEntry {
  const StoreCatalogEntry({
    required this.offeringId,
    required this.id,
    required this.productId,
    required this.priceString,
    required this.price,
    required this.currency,
    this.title = '',
    this.period = StorePeriod.other,
    this.pricePerMonthString,
    this.trial,
    this.intro,
  });

  /// The offering this entry was read from.
  final String offeringId;

  /// The entry's id inside its offering (RevenueCat's package id, such as
  /// `$rc_annual`).
  final String id;

  /// The store's own product id. A Play subscription's is
  /// `<product>:<base plan>`.
  final String productId;

  /// The product's name as the store words it.
  final String title;

  /// The billed amount as the store words it.
  final String priceString;

  /// The same amount as a number.
  final double price;

  /// The ISO currency code of [price].
  final String currency;

  final StorePeriod period;

  /// The store's own per month figure, where it gives one.
  final String? pricePerMonthString;

  /// A free first stretch, where the store offers one.
  final StoreIntroOffer? trial;

  /// A paid introductory price, where the store offers one.
  final StoreIntroOffer? intro;

  @override
  bool operator ==(Object other) =>
      other is StoreCatalogEntry &&
      other.offeringId == offeringId &&
      other.id == id &&
      other.productId == productId &&
      other.title == title &&
      other.priceString == priceString &&
      other.price == price &&
      other.currency == currency &&
      other.period == period &&
      other.pricePerMonthString == pricePerMonthString &&
      other.trial == trial &&
      other.intro == intro;

  @override
  int get hashCode => Object.hash(
    offeringId,
    id,
    productId,
    title,
    priceString,
    price,
    currency,
    period,
    pricePerMonthString,
    trial,
    intro,
  );

  @override
  String toString() => 'StoreCatalogEntry($offeringId/$id, $priceString)';
}

/// A named group of entries, as the store dashboard sets it up.
@immutable
final class StoreOffering {
  const StoreOffering({
    required this.id,
    required this.entries,
    this.annual,
    this.monthly,
  });

  final String id;

  /// Every entry in the offering, in the dashboard's order.
  final List<StoreCatalogEntry> entries;

  /// The entry the dashboard marked as the yearly one, if any.
  final StoreCatalogEntry? annual;

  /// The entry the dashboard marked as the monthly one, if any.
  final StoreCatalogEntry? monthly;

  @override
  bool operator ==(Object other) =>
      other is StoreOffering &&
      other.id == id &&
      listEquals(other.entries, entries) &&
      other.annual == annual &&
      other.monthly == monthly;

  @override
  int get hashCode => Object.hash(id, Object.hashAll(entries), annual, monthly);
}

/// Every offering the store has, and the one marked current.
@immutable
final class StoreOfferings {
  const StoreOfferings({this.current, this.all = const {}});

  /// The offering a paywall shows when it names none.
  final StoreOffering? current;

  /// Every offering, by id.
  final Map<String, StoreOffering> all;

  @override
  bool operator ==(Object other) =>
      other is StoreOfferings &&
      other.current == current &&
      mapEquals(other.all, all);

  @override
  int get hashCode => Object.hash(
    current,
    Object.hashAllUnordered(
      all.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
