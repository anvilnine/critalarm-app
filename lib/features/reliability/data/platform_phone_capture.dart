import 'dart:async';
import 'dart:convert';

import 'package:critalarm/core/ack/ack_queue_entry.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Takes a [PhoneCapture] from what the phone already keeps. Every source is
/// read and none is changed:
///
/// - the list the native push handlers write (`pending_push_events`), which
///   the push event drain empties on launch. [holdPendingRows] copies it
///   first, so call that before the drain runs;
/// - the native alarm snapshot: the incidents the phone set an alarm for and
///   the ones acknowledged on it. On iOS it also carries the rows the
///   notification extension wrote and has not handed over yet;
/// - the acknowledgements still waiting to reach the server;
/// - the alarm ids the platform reports while the app runs.
final class PlatformPhoneCapture {
  PlatformPhoneCapture({
    required SharedPreferences prefs,
    required this.readNative,
    required this.readAckQueue,
    this.alarmIds = const [],
    this.alarmingIds,
    this.pendingKey = 'pending_push_events',
    this.listCap = 50,
  }) : // The field is private and the parameter is public, so it cannot be
       // an initializing formal.
       // ignore: prefer_initializing_formals
       _prefs = prefs;

  final SharedPreferences _prefs;

  /// `AlarmHost.debugSnapshot`.
  final Future<Map<String, Object?>> Function() readNative;

  /// `AckQueue.entries`.
  final List<AckQueueEntry> Function() readAckQueue;

  /// Streams of incident ids whose alarm the platform set off or received:
  /// `AlarmHost.alarmsScheduled` and `PushHost.alarmPushes`.
  final List<Stream<String>> alarmIds;

  /// The incidents the alarm controller holds as ringing, read only.
  final Set<String> Function()? alarmingIds;

  /// `PushEventDrain.storageKey`.
  final String pendingKey;

  /// How many rows a native list keeps (`MAX_ROWS` in `PushEventLog.kt`,
  /// `maxRows` in `PushEventLog.swift`).
  final int listCap;

  final List<Object?> _heldRows = [];
  int? _heldLostBeforeMs;
  final Set<String> _heardIds = {};
  final List<StreamSubscription<String>> _subs = [];

  /// Starts listening for alarm ids. Safe to call more than once.
  void start() {
    if (_subs.isNotEmpty) return;
    for (final ids in alarmIds) {
      _subs.add(ids.listen(_heardIds.add));
    }
  }

  /// Copies the native list as it is on disk right now, with no wait, so a
  /// caller can run it on the line before the drain empties the list.
  void holdPendingRows() => _hold(_pendingRows());

  Future<PhoneCapture> take() async {
    // Native code writes the pending list while Dart is running.
    await _prefs.reload();
    _hold(_pendingRows());

    final rang = <String>{..._heardIds, ...?alarmingIds?.call()};
    final acked = <String>{
      for (final entry in readAckQueue())
        if (entry.action == AckAction.ack) entry.incidentId,
    };
    try {
      final native = await readNative();
      final events = native['push_events'];
      if (events is List) _hold(events);
      final incidents = native['incidents'];
      if (incidents is List) {
        for (final row in incidents) {
          if (row is! Map) continue;
          final id = row['id'];
          if (id is! String || id.isEmpty) continue;
          // `ring_until` is only written when an alarm push for the incident
          // was taken down the alarm path.
          if (row['ring_until'] is num) rang.add(id);
          if (row['acked_locally'] == true) acked.add(id);
        }
      }
      final marks = native['acked_set'];
      if (marks is List) {
        for (final row in marks) {
          final id = row is Map ? row['incident_id'] : null;
          if (id is String && id.isNotEmpty) acked.add(id);
        }
      }
    } on Object catch (_) {
      // The native read is a bonus. The rest still answers.
    }

    final capture = PhoneCapture(
      eventRows: List.unmodifiable(_heldRows),
      lostBeforeMs: _heldLostBeforeMs,
      rangIds: rang,
      acknowledgedHereIds: acked,
    );
    _heldRows.clear();
    _heldLostBeforeMs = null;
    return capture;
  }

  void _hold(List<Object?> rows) {
    if (rows.isEmpty) return;
    _heldRows.addAll(rows);
    if (rows.length < listCap) return;
    // A full list may have pushed older rows out.
    int? oldest;
    for (final row in rows) {
      final at = row is Map ? row['at_ms'] : null;
      if (at is num && (oldest == null || at < oldest)) oldest = at.toInt();
    }
    final held = _heldLostBeforeMs;
    if (oldest != null && (held == null || oldest > held)) {
      _heldLostBeforeMs = oldest;
    }
  }

  List<Object?> _pendingRows() {
    final raw = _prefs.getString(pendingKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } on FormatException {
      return const [];
    }
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }
}
