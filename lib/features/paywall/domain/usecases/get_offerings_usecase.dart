import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/services/store_catalog_entry.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';

/// Usecase to fetch the offerings on sale.
class GetOfferingsUsecase implements UseCase<NoParams, StoreOfferings> {
  const GetOfferingsUsecase(this._repository);

  final SubscriptionRepository _repository;

  @override
  Future<AppResult<StoreOfferings>> call(NoParams input) =>
      _repository.getOfferings();
}
