import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Usecase to purchase a RevenueCat package.
class PurchasePackageUsecase implements UseCase<Package, CustomerInfo> {
  const PurchasePackageUsecase(this._repository);

  final SubscriptionRepository _repository;

  @override
  Future<AppResult<CustomerInfo>> call(Package input) =>
      _repository.purchasePackage(input);
}
