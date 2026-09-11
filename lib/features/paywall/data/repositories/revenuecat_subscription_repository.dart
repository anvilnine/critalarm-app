import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Implementation of [SubscriptionRepository] backed by [RevenueCatService].
class RevenueCatSubscriptionRepository implements SubscriptionRepository {
  RevenueCatSubscriptionRepository(this._service);

  final RevenueCatService _service;

  @override
  Stream<CustomerInfo> get customerInfoStream => _service.customerInfoStream;

  @override
  Future<AppResult<bool>> isProActive() async {
    try {
      final info = await _service.getCustomerInfo();
      final entitlement =
          info.entitlements.all[SubscriptionTier.proEntitlement];
      return Success(entitlement?.isActive ?? false);
    } on PlatformException catch (e) {
      return _mapPlatformException(e).toFailure();
    } on Object catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<CustomerInfo>> getCustomerInfo() async {
    try {
      final info = await _service.getCustomerInfo();
      return Success(info);
    } on PlatformException catch (e) {
      return _mapPlatformException(e).toFailure();
    } on Object catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Offerings>> getOfferings() async {
    try {
      final offerings = await _service.getOfferings();
      return Success(offerings);
    } on PlatformException catch (e) {
      return _mapPlatformException(e).toFailure();
    } on Object catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<CustomerInfo>> purchasePackage(Package package) async {
    try {
      final info = await _service.purchasePackage(package);
      return Success(info);
    } on PlatformException catch (e) {
      return _mapPlatformException(e).toFailure();
    } on Object catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<CustomerInfo>> restorePurchases() async {
    try {
      final info = await _service.restorePurchases();
      return Success(info);
    } on PlatformException catch (e) {
      return _mapPlatformException(e).toFailure();
    } on Object catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  Failure _mapPlatformException(PlatformException e) {
    try {
      final code = PurchasesErrorHelper.getErrorCode(e);
      switch (code) {
        case PurchasesErrorCode.purchaseCancelledError:
          return const Failure.unexpected(message: 'Purchase was cancelled.');
        case PurchasesErrorCode.purchaseNotAllowedError:
          return const Failure.unsupported(
            message: 'Purchases are not allowed on this device or account.',
          );
        case PurchasesErrorCode.paymentPendingError:
          return const Failure.unexpected(
            message: 'Payment is pending authorization.',
          );
        case PurchasesErrorCode.productAlreadyPurchasedError:
          return const Failure.conflict(
            message: 'This subscription is already active.',
          );
        case PurchasesErrorCode.networkError:
          return const Failure.unexpected(
            message:
                'Network error. Please check your connection and try again.',
          );
        case PurchasesErrorCode.invalidCredentialsError:
          return const Failure.unauthorized(
            message: 'Invalid RevenueCat API key or configuration.',
          );
        case PurchasesErrorCode.storeProblemError:
          return const Failure.unexpected(
            message: 'The store encountered an error processing your request.',
          );
        case PurchasesErrorCode.unknownError:
        case PurchasesErrorCode.purchaseInvalidError:
        case PurchasesErrorCode.productNotAvailableForPurchaseError:
        case PurchasesErrorCode.receiptAlreadyInUseError:
        case PurchasesErrorCode.invalidReceiptError:
        case PurchasesErrorCode.missingReceiptFileError:
        case PurchasesErrorCode.unexpectedBackendResponseError:
        case PurchasesErrorCode.receiptInUseByOtherSubscriberError:
        case PurchasesErrorCode.invalidAppUserIdError:
        case PurchasesErrorCode.operationAlreadyInProgressError:
        case PurchasesErrorCode.unknownBackendError:
        case PurchasesErrorCode.invalidAppleSubscriptionKeyError:
        case PurchasesErrorCode.ineligibleError:
        case PurchasesErrorCode.insufficientPermissionsError:
        case PurchasesErrorCode.invalidSubscriberAttributesError:
        case PurchasesErrorCode.logOutWithAnonymousUserError:
        case PurchasesErrorCode.configurationError:
        case PurchasesErrorCode.unsupportedError:
        case PurchasesErrorCode.emptySubscriberAttributesError:
        case PurchasesErrorCode.productDiscountMissingIdentifierError:
        case PurchasesErrorCode.unknownNonNativeError:
        case PurchasesErrorCode
            .productDiscountMissingSubscriptionGroupIdentifierError:
        case PurchasesErrorCode.customerInfoError:
        case PurchasesErrorCode.systemInfoError:
        case PurchasesErrorCode.beginRefundRequestError:
        case PurchasesErrorCode.productRequestTimeout:
        case PurchasesErrorCode.apiEndpointBlocked:
        case PurchasesErrorCode.invalidPromotionalOfferError:
        case PurchasesErrorCode.offlineConnectionError:
        case PurchasesErrorCode
            .featureNotAvailableInCustomEntitlementsComputationMode:
        case PurchasesErrorCode.signatureVerificationFailed:
        case PurchasesErrorCode.featureNotSupportedWithStoreKit1:
        case PurchasesErrorCode.invalidWebPurchaseToken:
        case PurchasesErrorCode.purchaseBelongsToOtherUser:
        case PurchasesErrorCode.expiredWebPurchaseToken:
        case PurchasesErrorCode.testStoreSimulatedPurchaseError:
          return Failure.unexpected(
            message: e.message ?? 'RevenueCat error: ${code.name}',
          );
      }
    } on Object catch (_) {
      return Failure.unexpected(message: e.message ?? e.toString());
    }
  }
}
