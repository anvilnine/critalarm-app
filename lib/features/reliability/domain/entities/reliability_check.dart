import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:flutter/foundation.dart';

/// Names one check. A string underneath, so a later source adds an id without
/// editing an enum. Ids are not saved anywhere yet, but treat them as if they
/// were: a shipped id never changes.
extension type const ReliabilityCheckId(String value) {}

/// The ids the first sources use.
abstract final class ReliabilityCheckIds {
  static const notifications = ReliabilityCheckId('notifications');
  static const fullScreenAlarm = ReliabilityCheckId('full_screen_alarm');
  static const batteryOptimization = ReliabilityCheckId('battery_optimization');
  static const alarms = ReliabilityCheckId('alarms');
  static const timeSensitive = ReliabilityCheckId('time_sensitive');
  static const pushTokenConfirmed = ReliabilityCheckId('push_token_confirmed');
  static const lastPushReceived = ReliabilityCheckId('last_push_received');
  static const systemUpdate = ReliabilityCheckId('system_update');
}

/// One question about whether this phone will wake its owner, and the answer.
@immutable
final class ReliabilityCheck {
  const ReliabilityCheck({
    required this.id,
    required this.state,
    this.lastKnownGood,
    this.reason,
    this.fix,
  });

  /// A check with no meaning on this phone.
  const ReliabilityCheck.notOnThisPhone(this.id)
    : state = ReliabilityState.notOnThisPhone,
      lastKnownGood = null,
      reason = null,
      fix = null;

  final ReliabilityCheckId id;
  final ReliabilityState state;

  /// The last time the thing behind the check was known to work, where that
  /// means something: the relay's last accepted token, the last push. Null
  /// for a switch that is simply on or off.
  final DateTime? lastKnownGood;

  /// A short code for why the state is not [ReliabilityState.fine], such as
  /// `refused` or `stale`. It is for the screen to pick words with, and is
  /// null when the state is fine. Each source lists its own codes.
  final String? reason;

  /// What to offer, or null when there is nothing the user can do.
  final ReliabilityFix? fix;

  @override
  bool operator ==(Object other) =>
      other is ReliabilityCheck &&
      other.id == id &&
      other.state == state &&
      other.lastKnownGood == lastKnownGood &&
      other.reason == reason &&
      other.fix == fix;

  @override
  int get hashCode => Object.hash(id, state, lastKnownGood, reason, fix);

  @override
  String toString() =>
      'ReliabilityCheck(${id.value}, ${state.name}'
      '${reason == null ? '' : ', $reason'})';
}
