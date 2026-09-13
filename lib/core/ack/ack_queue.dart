import 'dart:async';
import 'dart:convert';

import 'package:critalarm/core/ack/ack_queue_entry.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Acks and closes that still have to reach the server.
///
/// Enqueuing writes to disk first and only then tries to send, so the alarm can
/// be stopped the moment the user taps Stop. Nothing here throws on a failed
/// send: a send that fails is left on disk with a later retry time and picked
/// up again on the next flush or the next app launch.
final class AckQueue {
  AckQueue(
    this._prefs,
    this._api, {
    this.analytics,
    DateTime Function()? clock,
    this.tickInterval = const Duration(seconds: 15),
  }) : _clock = clock ?? DateTime.now;


  static const storageKey = 'ack_queue_v1';

  /// First retry waits this long; each later one doubles it.
  static const baseBackoff = Duration(seconds: 2);

  /// Retries never wait longer than this between attempts.
  static const maxBackoff = Duration(minutes: 5);

  /// After this many failures the entry is dropped so the queue cannot grow
  /// without end on a server that is gone for good.
  static const maxAttempts = 12;

  final SharedPreferences _prefs;
  final ApiClient _api;
  final PushAnalytics? analytics;
  final DateTime Function() _clock;
  final Duration tickInterval;

  Timer? _ticker;
  int _sequence = 0;

  /// Enqueue and flush both read the whole list, change it and write it back,
  /// so they take turns instead of overlapping. Without this an enqueue that
  /// lands mid-flush is written and then overwritten by the flush.
  Future<void> _turn = Future<void>.value();

  /// Everything still waiting, oldest first.
  List<AckQueueEntry> get pending => _read();

  /// Adds one send and tries it right away. Completes once the entry is on
  /// disk, whether or not the send worked, so the caller can stop the alarm.
  Future<void> enqueue({
    required AckAction action,
    required String incidentId,
    int? alarmFiredAtMs,
  }) async {
    final now = _clock().millisecondsSinceEpoch;
    final entry = AckQueueEntry(
      id: '$now-${_sequence++}-$incidentId-${action.name}',
      action: action,
      incidentId: incidentId,
      enqueuedAtMs: now,
      alarmFiredAtMs: alarmFiredAtMs,
    );
    await _queued(() async => _write([..._read(), entry]));
    unawaited(flush());
  }

  /// Sends every entry whose retry time has passed.
  Future<void> flush() => _queued(_flushOnce);

  Future<T> _queued<T>(Future<T> Function() action) {
    final result = _turn.then((_) => action());
    _turn = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _flushOnce() async {
    final now = _clock();
    final remaining = <AckQueueEntry>[];
    for (final entry in _read()) {
      if (entry.nextAttemptAtMs > now.millisecondsSinceEpoch) {
        remaining.add(entry);
        continue;
      }
      final outcome = await _send(entry);
      _log(
        'ack_${outcome.name} action=${entry.action.name} '
        'incident_id=${entry.incidentId} attempts=${entry.attempts}',
      );
      switch (outcome) {
        case _SendOutcome.done:
          await _reportAcked(entry);
        case _SendOutcome.giveUp:
          break;
        case _SendOutcome.retry:
          final attempts = entry.attempts + 1;
          if (attempts >= maxAttempts) break;
          remaining.add(
            entry.copyWith(
              attempts: attempts,
              nextAttemptAtMs: now
                  .add(_backoff(attempts))
                  .millisecondsSinceEpoch,
            ),
          );
      }
    }
    await _write(remaining);
  }

  /// Flushes now and keeps retrying on a timer while the app is running.
  Future<void> start() async {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => unawaited(flush()));
    await flush();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Wait before attempt [attempts], doubling each time up to [maxBackoff].
  static Duration _backoff(int attempts) {
    final millis = baseBackoff.inMilliseconds * (1 << (attempts - 1));
    return millis >= maxBackoff.inMilliseconds
        ? maxBackoff
        : Duration(milliseconds: millis);
  }

  Future<_SendOutcome> _send(AckQueueEntry entry) async {
    try {
      switch (entry.action) {
        case AckAction.ack:
          await _api.ackIncident(entry.incidentId);
        case AckAction.close:
          await _api.closeIncident(entry.incidentId);
      }
      return _SendOutcome.done;
    } on ApiException catch (error) {
      // 409 means the incident already moved on, so the send has nothing left
      // to do. Other 4xx answers will not change on a retry either. 408 and
      // 429 are worth trying again.
      final status = error.statusCode;
      if (status == 408 || status == 429 || status >= 500) {
        return _SendOutcome.retry;
      }
      return _SendOutcome.giveUp;
    } on Object catch (_) {
      // Offline, DNS failure, timeout: keep it and try later.
      return _SendOutcome.retry;
    }
  }

  Future<void> _reportAcked(AckQueueEntry entry) async {
    if (entry.action != AckAction.ack) return;
    final firedAt = entry.alarmFiredAtMs;
    await analytics?.alarmAcked(
      incidentId: entry.incidentId,
      timeToAckMs: firedAt == null ? null : entry.enqueuedAtMs - firedAt,
    );
  }

  /// Goes to `adb logcat` under the `flutter` tag, which is how the offline
  /// retry is checked on a device.
  void _log(String message) => debugPrint('CritAlarmAck: $message');

  List<AckQueueEntry> _read() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AckQueueEntry.fromJson)
          .whereType<AckQueueEntry>()
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> _write(List<AckQueueEntry> entries) async {
    if (entries.isEmpty) {
      await _prefs.remove(storageKey);
      return;
    }
    await _prefs.setString(
      storageKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}

enum _SendOutcome { done, retry, giveUp }
