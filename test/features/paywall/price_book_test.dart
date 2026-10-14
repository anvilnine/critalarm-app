import 'package:critalarm/features/paywall/data/asset_price_book.dart';
import 'package:critalarm/features/paywall/domain/price_book.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw FlutterError('no such asset');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the bundled price book', () {
    late AssetPriceBook book;

    setUp(() async {
      book = await AssetPriceBook.load(rootBundle, locale: 'en_US');
    });

    test('words the three prices for en_US', () {
      expect(book.isEmpty, isFalse);
      expect(book.priceOf(PriceBookPlan.hostedMonthly)!.priceString, r'$4.99');
      expect(book.priceOf(PriceBookPlan.hostedYearly)!.priceString, r'$39.99');
      expect(book.priceOf(PriceBookPlan.proOnce)!.priceString, r'$19.99');
    });

    test('gives the yearly plan its price per month, rounded down', () {
      expect(
        book.priceOf(PriceBookPlan.hostedYearly)!.pricePerMonthString,
        r'$3.33',
      );
      expect(
        book.priceOf(PriceBookPlan.hostedMonthly)!.pricePerMonthString,
        isNull,
      );
      expect(book.priceOf(PriceBookPlan.proOnce)!.pricePerMonthString, isNull);
    });

    test('keeps the numbers, the currency and the store ids', () {
      final yearly = book.priceOf(PriceBookPlan.hostedYearly)!;
      expect(yearly.amount, 39.99);
      expect(yearly.currency, 'USD');
      expect(yearly.offeringId, isNull);
      expect(yearly.packageId, r'$rc_annual');
      expect(
        book.priceOf(PriceBookPlan.hostedMonthly)!.packageId,
        r'$rc_monthly',
      );
      final pro = book.priceOf(PriceBookPlan.proOnce)!;
      expect(pro.offeringId, 'pro');
      expect(pro.packageId, isNull);
    });
  });

  group('a book that cannot be read', () {
    test('a missing asset is an empty book', () async {
      final book = await AssetPriceBook.load(_BrokenBundle());
      expect(book.isEmpty, isTrue);
      for (final plan in PriceBookPlan.values) {
        expect(book.priceOf(plan), isNull);
      }
    });

    test('text that is not JSON is an empty book', () {
      expect(AssetPriceBook.parse('not json {').isEmpty, isTrue);
      expect(AssetPriceBook.parse('[1, 2]').isEmpty, isTrue);
      expect(AssetPriceBook.parse('').isEmpty, isTrue);
    });

    test('a plan that is not a price is left out, the others stay', () {
      final book = AssetPriceBook.parse('''
{
  "hosted": {
    "plans": {
      "yearly": {"amount": "free", "currency": "USD"},
      "monthly": {"amount": 4.99, "currency": "USD"}
    }
  },
  "pro": {"plans": {"once": {"amount": -1, "currency": "USD"}}}
}''', locale: 'en_US');
      expect(book.priceOf(PriceBookPlan.hostedYearly), isNull);
      expect(book.priceOf(PriceBookPlan.proOnce), isNull);
      expect(book.priceOf(PriceBookPlan.hostedMonthly)!.priceString, r'$4.99');
    });
  });

  test('the price per month never rounds up', () {
    expect(perMonthCents(3999), 333);
    expect(perMonthCents(1200), 100);
    expect(perMonthCents(1), 0);
  });
}
