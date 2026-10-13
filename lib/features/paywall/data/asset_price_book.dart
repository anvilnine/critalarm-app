import 'dart:convert';

import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Where the price book ships.
const priceBookAsset = 'assets/config/price_book.json';

/// A [PriceBook] over the bundled JSON file.
///
/// A file that is missing, broken or short of a field gives a book with
/// fewer prices, down to none. Reading never throws.
final class AssetPriceBook implements PriceBook {
  AssetPriceBook._(this._entries, this._locale);

  /// Reads the file's text. Anything that is not a price is left out.
  factory AssetPriceBook.parse(String source, {String? locale}) {
    final entries = <PriceBookPlan, _Entry>{};
    try {
      final root = jsonDecode(source);
      if (root is Map<String, dynamic>) {
        for (final plan in PriceBookPlan.values) {
          final entry = _entryOf(root, plan);
          if (entry != null) entries[plan] = entry;
        }
      }
    } on Object catch (_) {
      entries.clear();
    }
    return AssetPriceBook._(entries, locale);
  }

  /// Reads [priceBookAsset] from [bundle] once.
  static Future<AssetPriceBook> load(
    AssetBundle bundle, {
    String? locale,
    String key = priceBookAsset,
  }) async {
    try {
      return AssetPriceBook.parse(await bundle.loadString(key), locale: locale);
    } on Object catch (_) {
      return AssetPriceBook._(const {}, locale);
    }
  }

  final Map<PriceBookPlan, _Entry> _entries;

  /// Null reads the app's current locale each time a price is asked for.
  final String? _locale;

  @override
  bool get isEmpty => _entries.isEmpty;

  @override
  BookPrice? priceOf(PriceBookPlan plan) {
    final entry = _entries[plan];
    if (entry == null) return null;
    final format = NumberFormat.simpleCurrency(
      locale: _locale ?? Intl.getCurrentLocale(),
      name: entry.currency,
    );
    return BookPrice(
      plan: plan,
      amount: entry.cents / 100,
      currency: entry.currency,
      priceString: format.format(entry.cents / 100),
      pricePerMonthString: plan == PriceBookPlan.hostedYearly
          ? format.format(perMonthCents(entry.cents) / 100)
          : null,
      offeringId: entry.offering,
      packageId: entry.package,
    );
  }
}

class _Entry {
  const _Entry({
    required this.cents,
    required this.currency,
    this.offering,
    this.package,
  });

  final int cents;
  final String currency;
  final String? offering;
  final String? package;
}

const Map<PriceBookPlan, (String, String)> _sections = {
  PriceBookPlan.hostedYearly: ('hosted', 'yearly'),
  PriceBookPlan.hostedMonthly: ('hosted', 'monthly'),
  PriceBookPlan.proOnce: ('pro', 'once'),
};

_Entry? _entryOf(Map<String, dynamic> root, PriceBookPlan plan) {
  final (productKey, planKey) = _sections[plan]!;
  final product = root[productKey];
  if (product is! Map<String, dynamic>) return null;
  final plans = product['plans'];
  if (plans is! Map<String, dynamic>) return null;
  final raw = plans[planKey];
  if (raw is! Map<String, dynamic>) return null;
  final amount = raw['amount'];
  final currency = raw['currency'];
  if (amount is! num || !amount.isFinite || amount <= 0) return null;
  if (currency is! String || currency.length != 3) return null;
  final offering = product['offering'];
  final package = raw['package'];
  return _Entry(
    cents: (amount * 100).round(),
    currency: currency.toUpperCase(),
    offering: offering is String && offering.isNotEmpty ? offering : null,
    package: package is String && package.isNotEmpty ? package : null,
  );
}
