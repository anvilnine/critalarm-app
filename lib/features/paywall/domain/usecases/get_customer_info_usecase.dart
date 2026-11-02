import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/services/store_customer.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';

/// Usecase to get current customer info from the store.
class GetCustomerInfoUsecase implements UseCase<NoParams, StoreCustomer> {
  const GetCustomerInfoUsecase(this._repository);

  final SubscriptionRepository _repository;

  @override
  Future<AppResult<StoreCustomer>> call(NoParams input) =>
      _repository.getCustomerInfo();
}
