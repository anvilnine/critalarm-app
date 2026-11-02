import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/services/store_customer.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';

/// Usecase to restore previous purchases with the store.
class RestorePurchasesUsecase implements UseCase<NoParams, StoreCustomer> {
  const RestorePurchasesUsecase(this._repository);

  final SubscriptionRepository _repository;

  @override
  Future<AppResult<StoreCustomer>> call(NoParams input) =>
      _repository.restorePurchases();
}
