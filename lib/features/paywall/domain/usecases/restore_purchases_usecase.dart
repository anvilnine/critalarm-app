import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Usecase to restore previous purchases with RevenueCat.
class RestorePurchasesUsecase implements UseCase<NoParams, CustomerInfo> {
  const RestorePurchasesUsecase(this._repository);

  final SubscriptionRepository _repository;

  @override
  Future<AppResult<CustomerInfo>> call(NoParams input) =>
      _repository.restorePurchases();
}
