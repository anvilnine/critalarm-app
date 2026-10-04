import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// UI access comes from registration, plus the store while the server catches
/// up.
///
/// A purchase reaches RevenueCat before its webhook reaches our server, so for
/// a few seconds the registered tier still says `free`. [PlanChanges] carries
/// the store's answer for that gap, so the buyer sees Pro right away. The
/// server still enforces caps on its own.
///
/// The developer Force Pro switch can also say Pro, and it cannot say it in a
/// build anyone can install. See [ProOverride]: a store build is compiled with
/// [NoProOverride].
class AccountAccess {
  const AccountAccess(this.identity, {this.proOverride, this.planChanges});
  final DeviceIdentity? identity;

  /// Left null everywhere but tests, so the build's own override is used.
  final ProOverride? proOverride;

  /// Left null everywhere but tests, so the app's own [appPlanChanges] is used.
  final PlanChanges? planChanges;

  ProOverride get _override => proOverride ?? appProOverride;
  PlanChanges get _plan => planChanges ?? appPlanChanges;

  bool get isKnown => identity?.accountId != null;

  /// The tier the server put this device on. Ignores the developer switch.
  bool get isRegisteredPaid => isKnown && identity!.tier != 'free';

  /// True when the store says Pro but the server has not caught up yet. A cap
  /// the server hits in this window means "wait a moment", not "go Pro".
  bool get isProPending => !isRegisteredPaid && _plan.storeSaysPro;

  bool get isPaid =>
      isRegisteredPaid || _plan.storeSaysPro || _override.isForcingPro;
  bool get canRingUntilAcked => isPaid;
  AccountCaps? get caps => isKnown ? identity!.caps : null;

  /// The cap on critical topics to state next to a Critical switch, or
  /// null where there is none to state: a paid plan, and a server of the
  /// user's own ([isSelfHosted]), which has no plans. The one answer for
  /// every screen that draws that line.
  int? freeCriticalCap({required bool isSelfHosted}) =>
      isPaid || isSelfHosted ? null : (caps?.criticalTopics ?? 2);

  int criticalCount(Iterable<Topic> topics) =>
      topics.where((topic) => topic.critical).length;

  /// The "N critical topics used" line.
  ///
  /// A paid device never reads the Free limit. [isPaid] can be true while the
  /// registered caps still say free: the store confirmed a purchase and the
  /// webhook has not landed yet, or the developer Force Pro switch is on. In
  /// that window the line says the purchase is being confirmed, or shows the
  /// Pro wording, rather than "0 of 2".
  String criticalUsage(Iterable<Topic> topics) {
    if (isProPending) return LocaleKeys.account_plan_confirming.tr();
    final count = criticalCount(topics);
    if (isPaid && (!isKnown || caps!.criticalTopics != null)) {
      return LocaleKeys.account_critical_usage_unlimited.plural(count);
    }
    if (!isKnown) return LocaleKeys.account_plan_limits_unavailable.tr();
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
