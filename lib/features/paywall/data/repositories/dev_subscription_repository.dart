import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/paywall/data/repositories/in_memory_subscription_repository.dart';

/// Subscription repository for builds made with
/// --dart-define=SKIP_PAYWALL=true. Entitlement comes from the developer
/// switch in Settings instead of from the store.
class DevSubscriptionRepository extends InMemorySubscriptionRepository {
  DevSubscriptionRepository(this._proSwitch);

  final DevProSwitch _proSwitch;

  @override
  Future<AppResult<bool>> isProActive() async => Success(_proSwitch.value);
}
