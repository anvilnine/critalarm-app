import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// UI access comes from registration, never from store entitlement guesses.
///
/// The developer Force Pro switch is the one thing that can say otherwise, and
/// it cannot say it in a build anyone can install. See [ProOverride]: a store
/// build is compiled with [NoProOverride], so there [isPaid] is the registered
/// tier and nothing else.
class AccountAccess {
  const AccountAccess(this.identity, {this.proOverride});
  final DeviceIdentity? identity;

  /// Left null everywhere but tests, so the build's own override is used.
  final ProOverride? proOverride;

  ProOverride get _override => proOverride ?? appProOverride;

  bool get isKnown => identity?.accountId != null;

  /// The tier the server put this device on. Ignores the developer switch.
  bool get isRegisteredPaid => isKnown && identity!.tier != 'free';

  bool get isPaid => isRegisteredPaid || _override.isForcingPro;
  bool get canRingUntilAcked => isPaid;
  AccountCaps? get caps => isKnown ? identity!.caps : null;

  int criticalCount(Iterable<Topic> topics) =>
      topics.where((topic) => topic.critical).length;

  String criticalUsage(Iterable<Topic> topics) {
    if (!isKnown) return LocaleKeys.account_plan_limits_unavailable.tr();
    final count = criticalCount(topics);
    final limit = caps!.criticalTopics;
    return limit == null
        ? LocaleKeys.account_critical_usage_unlimited.plural(count)
        : LocaleKeys.account_critical_usage.tr(
            namedArgs: {'count': '$count', 'limit': '$limit'},
          );
  }

  bool canAddDevice(int registeredDevices) =>
      isKnown && (caps!.devices == null || registeredDevices < caps!.devices!);
}
