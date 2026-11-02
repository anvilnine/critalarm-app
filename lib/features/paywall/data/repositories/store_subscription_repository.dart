import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/core/store/services/store_customer.dart';
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// [SubscriptionRepository] over this build's [StoreBilling].
class StoreSubscriptionRepository implements SubscriptionRepository {
  StoreSubscriptionRepository(this._billing);

  final StoreBilling _billing;

  @override
  Stream<StoreCustomer> get customerInfoStream => _billing.customerChanges;

  @override
  Future<AppResult<bool>> isProActive() => _guard(() async {
    final info = await _billing.readCustomer();
    final entitlement =
        info.entitlements.all[SubscriptionTier.cloudEntitlement];
    return entitlement?.isActive ?? false;
  });

  @override
  Future<AppResult<StoreCustomer>> getCustomerInfo() =>
      _guard(_billing.readCustomer);

  @override
  Future<AppResult<StoreOfferings>> getOfferings() =>
      _guard(_billing.readOfferings);

  @override
  Future<AppResult<StoreCustomer>> purchasePackage(
    StoreCatalogEntry package,
  ) => _guard(() => _billing.purchase(package));

  @override
  Future<AppResult<StoreCustomer>> restorePurchases() =>
      _guard(_billing.restore);

  static Future<AppResult<T>> _guard<T extends Object>(
    Future<T> Function() call,
  ) async {
    try {
      return Success(await call());
    } on StoreBillingException catch (e) {
      return _failureOf(e).toFailure();
    } on Object catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  static Failure _failureOf(StoreBillingException e) => switch (e.error) {
    StoreBillingError.cancelled => Failure.unexpected(
      message: LocaleKeys.purchase_errors_purchase_cancelled.tr(),
    ),
    StoreBillingError.notAllowed => Failure.unsupported(
      message: LocaleKeys.purchase_errors_purchase_not_allowed.tr(),
    ),
    StoreBillingError.pending => Failure.unexpected(
      message: LocaleKeys.purchase_errors_payment_pending.tr(),
    ),
    StoreBillingError.alreadyOwned => Failure.conflict(
      message: LocaleKeys.purchase_errors_product_already_purchased.tr(),
    ),
    StoreBillingError.network => Failure.unexpected(
      message: LocaleKeys.purchase_errors_network_error.tr(),
    ),
    StoreBillingError.badConfiguration => Failure.unauthorized(
      message: e.message,
    ),
    StoreBillingError.storeProblem => Failure.unexpected(
      message: LocaleKeys.purchase_errors_store_problem.tr(),
    ),
    StoreBillingError.other => Failure.unexpected(message: e.message),
  };
}
