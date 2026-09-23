import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:flutter/foundation.dart';

/// The `max_ring_s` every topic starts with (api.md section 3.1). Used when
/// the topic is not in the shared list, so an alarm still holds focus.
const int defaultMaxRingS = 1800;

/// True while at least one open incident is still inside its ring window.
///
/// Stop, a swipe and Back keep the incident open, so focus stays. Only
/// acknowledging moves it to `acked`, which ends it.
bool alarmFocusOn({
  required List<Incident> incidents,
  required DateTime now,
  int? Function(String topic)? maxRingSeconds,
}) => focusedOpenIncidents(
  incidents: incidents,
  now: now,
  maxRingSeconds: maxRingSeconds,
).isNotEmpty;

/// The open incidents still inside their ring window.
///
/// The incident carries no `ring_until`, so the window is `opened_at` plus
/// the topic's `max_ring_s`, and 1800 seconds when the topic is not known.
List<Incident> focusedOpenIncidents({
  required List<Incident> incidents,
  required DateTime now,
  int? Function(String topic)? maxRingSeconds,
}) => incidents
    .where((incident) => _incidentFocused(incident, now, maxRingSeconds))
    .toList(growable: false);

bool _incidentFocused(
  Incident incident,
  DateTime now,
  int? Function(String topic)? maxRingSeconds,
) {
  if (!incident.isOpen) return false;
  final openedAt = incident.openedAt;
  // No opened time reads as under way: the incident is open and something
  // put it there.
  if (openedAt == null) return true;
  final maxRingS = maxRingSeconds?.call(incident.topic) ?? defaultMaxRingS;
  return now.isBefore(openedAt.add(Duration(seconds: maxRingS)));
}

/// The one source of "is an alarm under way on this phone".
///
/// Watches the shared incident list and flips [on] when the first open
/// incident appears and when the last one is acknowledged. The same change
/// writes the focused incident ids to the native side, so the iOS
/// notification delegate can keep other banners off while an alarm is up.
///
/// Built with nothing it is off for good, which is what a test that only
/// needs a quiet phone wants.
class AlarmFocus {
  AlarmFocus({
    Stream<List<Incident>>? incidents,
    List<Incident> Function()? current,
    int? Function(String topic)? maxRingSeconds,
    AlarmHost? host,
    DateTime Function()? now,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _maxRingSeconds = maxRingSeconds,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _host = host,
       _now = now ?? DateTime.now {
    _apply(current?.call() ?? const <Incident>[]);
    if (incidents != null) _sub = incidents.listen(_apply);
  }

  final int? Function(String topic)? _maxRingSeconds;
  final AlarmHost? _host;
  final DateTime Function() _now;

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<Incident>>? _sub;

  /// The newest shared list. [on] is answered from this and the clock, so a
  /// ring window that ran out with no list change still reads as off.
  List<Incident> _incidents = const <Incident>[];
  List<String> _openIds = const <String>[];
  bool _wasOn = false;
  bool _hasWritten = false;

  /// True while at least one open incident is inside its ring window.
  bool get on => alarmFocusOn(
    incidents: _incidents,
    now: _now(),
    maxRingSeconds: _maxRingSeconds,
  );

  /// Emits whenever [on] changes with the list.
  Stream<bool> get stream => _controller.stream;

  void _apply(List<Incident> incidents) {
    _incidents = incidents;
    final focused = focusedOpenIncidents(
      incidents: incidents,
      now: _now(),
      maxRingSeconds: _maxRingSeconds,
    );
    final isOn = focused.isNotEmpty;
    if (isOn != _wasOn) {
      _wasOn = isOn;
      _controller.add(isOn);
    }
    final ids = [for (final incident in focused) incident.id];
    if (!_hasWritten || !listEquals(ids, _openIds)) {
      _hasWritten = true;
      _openIds = ids;
      unawaited(_host?.setOpenIncidents(ids));
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
