import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/alarm_arrivals.dart';

/// [AlarmArrivals] from what the platform reports.
///
/// Three sources, the ones the app opens the alarm screen from:
///
/// - an alarm push that reached the running app ([PushHost.alarmPushes]);
/// - an alarm the phone scheduled for a push ([AlarmHost.alarmsScheduled]);
/// - a tapped alarm notification, or the full-screen alarm opening the app
///   ([PushHost.deepLinks] on an incident route).
class PlatformAlarmArrivals implements AlarmArrivals {
  PlatformAlarmArrivals({
    required PushHost push,
    required AlarmHost alarm,
    this.alarmingIncidentIds,
  }) : _alarm = alarm {
    _subs = [
      push.alarmPushes.listen(_ids.add),
      alarm.alarmsScheduled.listen(_ids.add),
      push.deepLinks.listen((location) {
        final id = incidentIdOfRoute(location);
        if (id != null) _ids.add(id);
      }),
    ];
  }

  final AlarmHost _alarm;

  /// Incidents with an alarm set or ringing, as the app's alarm controller
  /// holds them in memory.
  final Set<String> Function()? alarmingIncidentIds;

  final _ids = StreamController<String>.broadcast();
  late final List<StreamSubscription<Object?>> _subs;

  static const _incidentRoute = '/incidents/';

  /// The incident id in an `/incidents/<id>` route, or null for any other.
  static String? incidentIdOfRoute(String location) {
    if (!location.startsWith(_incidentRoute)) return null;
    final id = Uri.decodeComponent(location.substring(_incidentRoute.length));
    return id.isEmpty ? null : id;
  }

  @override
  Stream<String> get incidentIds => _ids.stream;

  @override
  Future<bool> isUp(String incidentId) async {
    if (alarmingIncidentIds?.call().contains(incidentId) ?? false) {
      return true;
    }
    if (await _alarm.receivedAlarmFor(incidentId)) return true;
    return (await _alarm.showingIncidentIds()).contains(incidentId);
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _ids.close();
  }
}
