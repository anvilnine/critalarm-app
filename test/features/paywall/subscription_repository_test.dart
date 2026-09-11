import 'package:critalarm/features/paywall/data/repositories/in_memory_subscription_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  group('InMemorySubscriptionRepository', () {
    late InMemorySubscriptionRepository repository;

    setUp(() {
      repository = InMemorySubscriptionRepository();
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('isProActive returns initial false state', () async {
      final result = await repository.isProActive();
      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull(), isFalse);
    });

    test('purchasePackage sets isPro to true and emits CustomerInfo', () async {
      const package = Package(
        'yearly',
        PackageType.annual,
        StoreProduct('yearly', 'Y', 'Y', 19.99, r'$19.99', 'USD'),
        PresentedOfferingContext('default', null, null),
      );

      final customerInfoFuture = repository.customerInfoStream.first;

      final purchaseResult = await repository.purchasePackage(package);
      expect(purchaseResult.isSuccess(), isTrue);

      final customerInfo = await customerInfoFuture;
      expect(
        customerInfo.entitlements.all['crit_alarm_pro']?.isActive,
        isTrue,
      );

      final isProResult = await repository.isProActive();
      expect(isProResult.getOrNull(), isTrue);
    });

    test('restorePurchases restores pro entitlement', () async {
      final restoreResult = await repository.restorePurchases();
      expect(restoreResult.isSuccess(), isTrue);

      final isProResult = await repository.isProActive();
      expect(isProResult.getOrNull(), isTrue);
    });
  });
}
