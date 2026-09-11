import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';

/// Usecase to check if the user has an active `crit_alarm_pro` entitlement.
class CheckProEntitlementUsecase implements UseCase<NoParams, bool> {
  const CheckProEntitlementUsecase(this._repository);

  final SubscriptionRepository _repository;

  @override
  Future<AppResult<bool>> call(NoParams input) => _repository.isProActive();
}
