import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/core/store/services/store_customer.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';

/// Usecase to buy one catalog entry.
class PurchasePackageUsecase
    implements UseCase<StoreCatalogEntry, StoreCustomer> {
  const PurchasePackageUsecase(this._repository);

  final SubscriptionRepository _repository;

  @override
  Future<AppResult<StoreCustomer>> call(StoreCatalogEntry input) =>
      _repository.purchasePackage(input);
}
