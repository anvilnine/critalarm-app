import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:flutter/foundation.dart';

/// How a plan bills.
enum StorePlanKind { monthly, yearly, oneTime }

/// One plan the store has on sale, in the app's own words. It carries no
/// store type.
@immutable
final class StorePlan {
  const StorePlan({
    required this.id,
    required this.product,
    required this.kind,
    required this.priceString,
    required this.price,
    required this.currency,
    this.pricePerMonthString,
  });

  /// The price book's name for the plan. What `StoreCatalog.buy` takes back.
  final PriceBookPlan id;

  final PaywallProduct product;
  final StorePlanKind kind;

  /// The billed amount, as the store words it.
  final String priceString;

  /// The same amount as a number.
  final double price;

  /// The ISO currency code of [price].
  final String currency;

  /// The store's own per month figure, where it gives one.
  final String? pricePerMonthString;

  @override
  bool operator ==(Object other) =>
      other is StorePlan &&
      other.id == id &&
      other.product == product &&
      other.kind == kind &&
      other.priceString == priceString &&
      other.price == price &&
      other.currency == currency &&
      other.pricePerMonthString == pricePerMonthString;

  @override
  int get hashCode => Object.hash(
    id,
    product,
    kind,
    priceString,
    price,
    currency,
    pricePerMonthString,
  );

  @override
  String toString() => 'StorePlan(${id.name}, $priceString)';
}

/// How a purchase or a restore at the store ended.
enum StoreOutcome {
  /// The store finished it.
  done,

  /// The buyer backed out.
  cancelled,

  /// The store reported a problem, or could not be asked.
  problem,
}

/// The store, as the paywall sees it: what is on sale for a product, buying
/// one plan, and restoring. Every method answers and none throws.
abstract interface class StoreCatalog {
  /// The plans the store has on sale for [product], in the price book's
  /// order. A plan the store does not have is left out, and a store that
  /// cannot be asked gives none.
  Future<List<StorePlan>> plansFor(PaywallProduct product);

  /// Buys [plan]. A plan the store did not send in the last read is a
  /// problem.
  Future<StoreOutcome> buy(StorePlan plan);

  /// Asks the store to hand back what this account already bought.
  Future<StoreOutcome> restore();
}
