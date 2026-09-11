import 'dart:async';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// In-memory implementation of [SubscriptionRepository] for testing and
/// offline runs.
class InMemorySubscriptionRepository implements SubscriptionRepository {
  InMemorySubscriptionRepository({
    this.isPro = false,
    this.offerings,
    this.customerInfo,
  });

  bool isPro;
  final Offerings? offerings;
  CustomerInfo? customerInfo;
  final _customerInfoController = StreamController<CustomerInfo>.broadcast();

  @override
  Stream<CustomerInfo> get customerInfoStream => _customerInfoController.stream;

  @override
  Future<AppResult<bool>> isProActive() async => Success(isPro);

  @override
  Future<AppResult<CustomerInfo>> getCustomerInfo() async {
    final existingInfo = customerInfo;
    if (existingInfo != null) {
      return Success(existingInfo);
    }
    final mockInfo = CustomerInfo.fromJson(const <String, dynamic>{
      'entitlements': <String, dynamic>{
        'all': <String, dynamic>{},
        'active': <String, dynamic>{},
      },
      'allPurchaseDates': <String, String?>{},
      'activeSubscriptions': <String>[],
      'allPurchasedProductIdentifiers': <String>[],
      'nonSubscriptionTransactions': <dynamic>[],
      'firstSeen': '2026-01-01T00:00:00Z',
      'originalAppUserId': 'mock_user',
      'allExpirationDates': <String, String?>{},
      'requestDate': '2026-01-01T00:00:00Z',
    });
    return Success(mockInfo);
  }

  @override
  Future<AppResult<Offerings>> getOfferings() async {
    final existingOfferings = offerings;
    if (existingOfferings != null) {
      return Success(existingOfferings);
    }
    final mockOfferings = Offerings.fromJson(const <String, dynamic>{
      'all': <String, dynamic>{},
    });
    return Success(mockOfferings);
  }

  @override
  Future<AppResult<CustomerInfo>> purchasePackage(Package package) async {
    isPro = true;
    final info = CustomerInfo.fromJson(const <String, dynamic>{
      'entitlements': <String, dynamic>{
        'all': <String, dynamic>{
          'crit_alarm_pro': <String, dynamic>{
            'identifier': 'crit_alarm_pro',
            'isActive': true,
            'willRenew': true,
            'periodType': 'NORMAL',
            'latestPurchaseDate': '2026-01-01T00:00:00Z',
            'originalPurchaseDate': '2026-01-01T00:00:00Z',
            'expirationDate': null,
            'store': 'APP_STORE',
            'productIdentifier': 'lifetime',
            'isSandbox': true,
            'ownershipType': 'PURCHASED',
          },
        },
        'active': <String, dynamic>{
          'crit_alarm_pro': <String, dynamic>{
            'identifier': 'crit_alarm_pro',
            'isActive': true,
            'willRenew': true,
            'periodType': 'NORMAL',
            'latestPurchaseDate': '2026-01-01T00:00:00Z',
            'originalPurchaseDate': '2026-01-01T00:00:00Z',
            'expirationDate': null,
            'store': 'APP_STORE',
            'productIdentifier': 'lifetime',
            'isSandbox': true,
            'ownershipType': 'PURCHASED',
          },
        },
      },
      'allPurchaseDates': <String, String?>{'lifetime': '2026-01-01T00:00:00Z'},
      'activeSubscriptions': <String>[],
      'allPurchasedProductIdentifiers': <String>['lifetime'],
      'nonSubscriptionTransactions': <dynamic>[],
      'firstSeen': '2026-01-01T00:00:00Z',
      'originalAppUserId': 'mock_user',
      'allExpirationDates': <String, String?>{},
      'requestDate': '2026-01-01T00:00:00Z',
    });
    customerInfo = info;
    _customerInfoController.add(info);
    return Success(info);
  }

  @override
  Future<AppResult<CustomerInfo>> restorePurchases() async {
    const pkg = Package(
      'lifetime',
      PackageType.lifetime,
      StoreProduct(
        'lifetime',
        'Crit Alarm Pro Lifetime',
        'Crit Alarm Pro Lifetime',
        0,
        r'$0.00',
        'USD',
      ),
      PresentedOfferingContext('default', null, null),
    );
    return purchasePackage(pkg);
  }

  Future<void> dispose() async {
    await _customerInfoController.close();
  }
}
