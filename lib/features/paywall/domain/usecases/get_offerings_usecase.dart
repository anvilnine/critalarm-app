import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Usecase to fetch available offerings from RevenueCat.
class GetOfferingsUsecase implements UseCase<NoParams, Offerings> {
  const GetOfferingsUsecase(this._repository);

  final SubscriptionRepository _repository;

  @override
  Future<AppResult<Offerings>> call(NoParams input) =>
      _repository.getOfferings();
}
