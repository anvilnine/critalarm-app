import 'package:critalarm/features/paywall/domain/entities/plan_saving.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('yearlySavingPercent', () {
    test('rounds the saving against twelve months of monthly', () {
      expect(
        yearlySavingPercent(monthlyPrice: 4, yearlyPrice: 32),
        33,
      );
      expect(
        yearlySavingPercent(monthlyPrice: 10, yearlyPrice: 90),
        25,
      );
    });

    test('is null while either price is unknown', () {
      expect(yearlySavingPercent(monthlyPrice: null, yearlyPrice: 30), isNull);
      expect(yearlySavingPercent(monthlyPrice: 3, yearlyPrice: null), isNull);
    });

    test('is null when yearly is not cheaper', () {
      expect(yearlySavingPercent(monthlyPrice: 3, yearlyPrice: 36), isNull);
      expect(yearlySavingPercent(monthlyPrice: 3, yearlyPrice: 40), isNull);
    });

    test('is null for a zero or negative price', () {
      expect(yearlySavingPercent(monthlyPrice: 0, yearlyPrice: 10), isNull);
      expect(yearlySavingPercent(monthlyPrice: 3, yearlyPrice: 0), isNull);
    });
  });
}
