import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:flutter/foundation.dart';

/// One plan the price book holds a price for.
enum PriceBookPlan {
  hostedYearly(PaywallProduct.hosted),
  hostedMonthly(PaywallProduct.hosted),
  proOnce(PaywallProduct.pro);

  const PriceBookPlan(this.product);

  final PaywallProduct product;
}

/// What the price book says one plan costs, worded for the screen.
@immutable
final class BookPrice {
  const BookPrice({
    required this.plan,
    required this.amount,
    required this.currency,
    required this.priceString,
    this.pricePerMonthString,
    this.offeringId,
    this.packageId,
  });

  final PriceBookPlan plan;

  /// The billed amount as a number.
  final double amount;

  /// The ISO currency code.
  final String currency;

  /// The billed amount, formatted for the current locale and [currency].
  final String priceString;

  /// The yearly plan's price for one month, rounded down to the cent. Null
  /// for every other plan.
  final String? pricePerMonthString;

  /// The RevenueCat offering this plan is read from. Null is the current one.
  final String? offeringId;

  /// The RevenueCat package in that offering. Null is its only package.
  final String? packageId;

  @override
  bool operator ==(Object other) =>
      other is BookPrice &&
      other.plan == plan &&
      other.amount == amount &&
      other.currency == currency &&
      other.priceString == priceString &&
      other.pricePerMonthString == pricePerMonthString &&
      other.offeringId == offeringId &&
      other.packageId == packageId;

  @override
  int get hashCode => Object.hash(
    plan,
    amount,
    currency,
    priceString,
    pricePerMonthString,
    offeringId,
    packageId,
  );

  @override
  String toString() => 'BookPrice(${plan.name}, $priceString)';
}

/// The prices the app shows when the store has not sent its own.
///
/// They come from a file that ships with the app. A store price always wins
/// over the book's, and the renewal reminder never reads the book.
abstract interface class PriceBook {
  /// The price of [plan], or null when the book has none.
  BookPrice? priceOf(PriceBookPlan plan);

  /// Whether the book holds no price at all.
  bool get isEmpty;
}

/// A book with no price in it: the one a missing or broken file gives.
final class EmptyPriceBook implements PriceBook {
  const EmptyPriceBook();

  @override
  BookPrice? priceOf(PriceBookPlan plan) => null;

  @override
  bool get isEmpty => true;
}

/// A yearly price in cents, shared out over twelve months and rounded down
/// to the cent.
int perMonthCents(int yearlyCents) => yearlyCents ~/ 12;

/// The book the running app reads, for the places that have no way to be
/// handed one (a tile, a capture). The composition root sets it once at
/// startup, after the file is read.
abstract final class PriceBookInUse {
  static PriceBook current = const EmptyPriceBook();
}
