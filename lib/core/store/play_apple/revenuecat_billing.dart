import 'package:critalarm/core/store/play_apple/revenuecat_service.dart';
import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/core/store/services/store_customer.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// [StoreBilling] over RevenueCat, for Google Play and the App Store.
///
/// It turns RevenueCat's types into the store-neutral ones and RevenueCat's
/// [PlatformException]s into [StoreBillingException]s. It keeps the
/// packages behind the entries it handed out, so [purchase] can buy the
/// exact package an entry came from.
final class RevenueCatBilling implements StoreBilling {
  RevenueCatBilling([RevenueCatService? service])
    : service = service ?? RevenueCatService();

  /// The SDK wrapper. `lib/app/di.dart` configures it with the store key.
  final RevenueCatService service;

  /// The packages behind the entries last read, by offering and package id.
  final Map<String, Package> _packages = {};

  @override
  bool get isConfigured => service.isConfigured;

  @override
  Stream<StoreCustomer> get customerChanges =>
      service.customerInfoStream.map(storeCustomerOf);

  @override
  Future<StoreCustomer> readCustomer() =>
      _store(() async => storeCustomerOf(await service.getCustomerInfo()));

  @override
  Future<StoreOfferings> readOfferings() => _store(() async {
    final offerings = await service.getOfferings();
    offerings.all.values.forEach(_keep);
    final current = offerings.current;
    if (current != null) _keep(current);
    return storeOfferingsOf(offerings);
  });

  void _keep(Offering offering) {
    for (final package in offering.availablePackages) {
      _packages[_key(offering.identifier, package.identifier)] = package;
    }
  }

  static String _key(String offeringId, String packageId) =>
      '$offeringId\u0000$packageId';

  @override
  Future<StoreCustomer> purchase(StoreCatalogEntry entry) => _store(() async {
    final package = _packages[_key(entry.offeringId, entry.id)];
    if (package == null) {
      throw StateError('No store package behind $entry');
    }
    return storeCustomerOf(await service.purchasePackage(package));
  });

  @override
  Future<StoreCustomer> restore() =>
      _store(() async => storeCustomerOf(await service.restorePurchases()));

  // The account calls below hand back whatever the SDK throws, as they did
  // before the seam, except [logOut]. Their callers treat any throw the
  // same way.

  @override
  Future<void> identifyAccount(String accountId) =>
      service.identifyAccount(accountId);

  /// RevenueCat answers `logOutWithAnonymousUserError` when the store user
  /// is already anonymous. That is the state [logOut] asks for, so it
  /// returns quietly. Any other store error comes back as a
  /// [StoreBillingException].
  @override
  Future<void> logOut() async {
    try {
      await service.logOut();
    } on PlatformException catch (error) {
      if (_isAnonymousLogOut(error)) return;
      throw storeBillingExceptionOf(error);
    }
  }

  static bool _isAnonymousLogOut(PlatformException error) {
    try {
      return PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.logOutWithAnonymousUserError;
    } on Object catch (_) {
      // A code that is not a number is not the store's anonymous answer.
      return false;
    }
  }

  @override
  Future<void> invalidateCustomerCache() =>
      service.invalidateCustomerInfoCache();

  /// Runs [call] and turns a RevenueCat error into a [StoreBillingException].
  /// Every other throw passes through as it is.
  static Future<T> _store<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error) {
      throw storeBillingExceptionOf(error);
    }
  }
}

/// The neutral entry for [package], read from the offering [offeringId].
StoreCatalogEntry storeCatalogEntryOf(
  Package package, {
  required String offeringId,
}) {
  final product = package.storeProduct;
  final introductory = product.introductoryPrice;
  final offer = introductory == null
      ? null
      : StoreIntroOffer(
          priceString: introductory.priceString,
          price: introductory.price,
          period: introductory.period,
          cycles: introductory.cycles,
        );
  final isFree = introductory != null && introductory.price == 0;
  return StoreCatalogEntry(
    offeringId: offeringId,
    id: package.identifier,
    productId: product.identifier,
    title: product.title,
    priceString: product.priceString,
    price: product.price,
    currency: product.currencyCode,
    period: switch (package.packageType) {
      PackageType.annual => StorePeriod.yearly,
      PackageType.monthly => StorePeriod.monthly,
      PackageType.lifetime => StorePeriod.lifetime,
      PackageType.custom ||
      PackageType.unknown ||
      PackageType.weekly ||
      PackageType.twoMonth ||
      PackageType.threeMonth ||
      PackageType.sixMonth => StorePeriod.other,
    },
    pricePerMonthString: product.pricePerMonthString,
    trial: isFree ? offer : null,
    intro: isFree ? null : offer,
  );
}

/// The neutral offering for [offering].
StoreOffering storeOfferingOf(Offering offering) {
  StoreCatalogEntry? entry(Package? package) => package == null
      ? null
      : storeCatalogEntryOf(package, offeringId: offering.identifier);
  return StoreOffering(
    id: offering.identifier,
    entries: [
      for (final package in offering.availablePackages) entry(package)!,
    ],
    annual: entry(offering.annual),
    monthly: entry(offering.monthly),
  );
}

/// The neutral offerings for [offerings].
StoreOfferings storeOfferingsOf(Offerings offerings) {
  final current = offerings.current;
  return StoreOfferings(
    current: current == null ? null : storeOfferingOf(current),
    all: {
      for (final MapEntry(:key, :value) in offerings.all.entries)
        key: storeOfferingOf(value),
    },
  );
}

/// The neutral customer for [info].
StoreCustomer storeCustomerOf(CustomerInfo info) {
  final all = info.entitlements.all;
  final active = info.entitlements.active; // access-ok: a copy, decides none
  return StoreCustomer(
    entitlements: StoreEntitlements(
      all: {
        for (final MapEntry(:key, :value) in all.entries)
          key: _entitlementOf(value),
      },
      active: {
        for (final MapEntry(:key, :value) in active.entries)
          key: _entitlementOf(value),
      },
    ),
    managementUrl: info.managementURL,
  );
}

StoreEntitlement _entitlementOf(EntitlementInfo info) => StoreEntitlement(
  id: info.identifier,
  isActive: info.isActive,
  willRenew: info.willRenew,
  productId: info.productIdentifier,
  productPlanId: info.productPlanIdentifier,
  expirationDate: info.expirationDate,
  billingIssueDetectedAt: info.billingIssueDetectedAt,
);

/// The neutral error for a RevenueCat [PlatformException].
StoreBillingException storeBillingExceptionOf(PlatformException error) {
  final PurchasesErrorCode code;
  try {
    code = PurchasesErrorHelper.getErrorCode(error);
  } on Object catch (_) {
    return StoreBillingException(
      StoreBillingError.other,
      error.message ?? error.toString(),
    );
  }
  final kind = switch (code) {
    PurchasesErrorCode.purchaseCancelledError => StoreBillingError.cancelled,
    PurchasesErrorCode.purchaseNotAllowedError => StoreBillingError.notAllowed,
    PurchasesErrorCode.paymentPendingError => StoreBillingError.pending,
    PurchasesErrorCode.productAlreadyPurchasedError =>
      StoreBillingError.alreadyOwned,
    PurchasesErrorCode.networkError => StoreBillingError.network,
    PurchasesErrorCode.invalidCredentialsError =>
      StoreBillingError.badConfiguration,
    PurchasesErrorCode.storeProblemError => StoreBillingError.storeProblem,
    _ => StoreBillingError.other,
  };
  return StoreBillingException(
    kind,
    switch (kind) {
      StoreBillingError.badConfiguration =>
        'Invalid RevenueCat API key or configuration.',
      StoreBillingError.other =>
        error.message ?? 'RevenueCat error: ${code.name}',
      _ => error.message,
    },
  );
}
