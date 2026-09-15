import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/topic.dart';

/// UI access comes from registration, never from store entitlement guesses.
class AccountAccess {
  const AccountAccess(this.identity);
  final DeviceIdentity? identity;
  bool get isKnown => identity?.accountId != null;
  bool get isPaid => isKnown && identity!.tier != 'free';
  bool get canRingUntilAcked => isPaid;
  AccountCaps? get caps => isKnown ? identity!.caps : null;

  int criticalCount(Iterable<Topic> topics) =>
      topics.where((topic) => topic.critical).length;

  String criticalUsage(Iterable<Topic> topics) {
    if (!isKnown) return 'Plan limits unavailable';
    final count = criticalCount(topics);
    final limit = caps!.criticalTopics;
    return limit == null
        ? '$count critical topics used · Unlimited'
        : '$count of $limit critical topics used';
  }

  bool canAddDevice(int registeredDevices) =>
      isKnown && (caps!.devices == null || registeredDevices < caps!.devices!);
}
