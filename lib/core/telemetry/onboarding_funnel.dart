import 'dart:convert';
import 'dart:math';

import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the setup funnel stands with the user's analytics choice.
enum OnboardingFunnelState {
  /// Nobody has answered. Events wait on the phone.
  unanswered,

  /// Analytics is on. Events go straight to the gate.
  optedIn,

  /// Analytics was declined or switched off. Events are dropped.
  optedOut,

  /// Nobody answered for a week, so the wait is over for this install.
  expired,
}

/// Counts how far people get through setup, and only if they let it.
///
/// Each step sends two events, one when it opens and one when it is
/// finished. The consent question comes on the last step, so until the user
/// answers, the events wait in shared preferences. Nothing is passed to the
/// gate, and no analytics call is made, before an opt-in.
///
/// - Opt in: the waiting events go to [TelemetryGate.logEvent] in order, once,
///   and the list is deleted. Later events go straight through.
/// - Opt out, or analytics switched off again: the list is deleted and
///   nothing is sent.
/// - No answer: the list is deleted 7 days after its first event, and nothing
///   is held for this install afterwards.
///
/// The list holds at most 100 events. When it is full a new event is
/// dropped, and the ones already there stay as they were.
///
/// An event is the step id, the flow id and the milliseconds since the
/// previous event. Both ids are checked before they become a parameter.
final class OnboardingFunnel {
  OnboardingFunnel({
    required this._prefs,
    required this._gate,
    required Set<String> stepIds,
    DateTime Function()? clock,
  }) : _analytics = OnboardingAnalytics(_gate),
       _stepIds = Set.unmodifiable(stepIds),
       _clock = clock ?? DateTime.now;

  /// The events waiting for an answer. A JSON list.
  static const bufferKey = 'pending_onboarding_events';

  /// What the user's answer was: `in`, `out` or `expired`. Absent while
  /// nobody has answered. The analytics preference alone cannot say, since it
  /// reads false both for "never asked" and for "said no".
  static const stateKey = 'onboarding_funnel_state';

  static const maxBuffered = 100;
  static const maxAge = Duration(days: 7);

  static final _flowIdPattern = RegExp(r'^[A-Za-z0-9._-]{1,40}$');

  static const _viewed = 'v';
  static const _completed = 'c';
  static const _fields = {'k', 'step', 'flow_id', 'ms', 'at'};

  final SharedPreferences _prefs;
  final TelemetryGate _gate;
  final OnboardingAnalytics _analytics;
  final Set<String> _stepIds;
  final DateTime Function() _clock;

  DateTime? _previousAt;
  Future<void> _queue = Future.value();

  OnboardingFunnelState get state => switch (_prefs.getString(stateKey)) {
    'in' => OnboardingFunnelState.optedIn,
    'out' => OnboardingFunnelState.optedOut,
    'expired' => OnboardingFunnelState.expired,
    _ => OnboardingFunnelState.unanswered,
  };

  /// A step opened. [isReplay] is a look at the screens from Settings or
  /// developer settings, which records nothing.
  Future<void> stepViewed(
    String step,
    String flowId, {
    bool isReplay = false,
  }) => _record(_viewed, step, flowId, isReplay: isReplay);

  /// A step finished.
  Future<void> stepCompleted(
    String step,
    String flowId, {
    bool isReplay = false,
  }) => _record(_completed, step, flowId, isReplay: isReplay);

  /// The app opened. [analyticsOn] is the saved analytics preference. This
  /// is where a leftover list is sent, deleted or aged out.
  Future<void> start({required bool analyticsOn}) => _enqueue(() async {
    if (analyticsOn) return _optIn();
    if (state == OnboardingFunnelState.optedIn) return _optOut();
    await _expireIfStale();
  });

  /// The user chose, anywhere: the setup switch, Settings > Privacy or the
  /// Home consent sheet.
  Future<void> answered({required bool isOn}) =>
      _enqueue(() => isOn ? _optIn(turnGateOn: true) : _optOut());

  Future<void> _record(
    String kind,
    String step,
    String flowId, {
    required bool isReplay,
  }) {
    if (isReplay) return Future.value();
    if (!_stepIds.contains(step) || !_flowIdPattern.hasMatch(flowId)) {
      return Future.value();
    }
    // Worked out now, not when the queue gets to it, so it is the time
    // between the events and not between the writes.
    final now = _clock();
    final previous = _previousAt;
    _previousAt = now;
    final ms = previous == null
        ? 0
        : max(0, now.difference(previous).inMilliseconds);
    return _enqueue(() => _handle(kind, step, flowId, ms, now));
  }

  Future<void> _handle(
    String kind,
    String step,
    String flowId,
    int ms,
    DateTime now,
  ) async {
    switch (state) {
      case OnboardingFunnelState.optedIn:
        await _send(kind, step, flowId, ms);
      case OnboardingFunnelState.optedOut:
      case OnboardingFunnelState.expired:
        return;
      case OnboardingFunnelState.unanswered:
        await _expireIfStale();
        if (state == OnboardingFunnelState.expired) return;
        final events = await _readBuffer() ?? <Map<String, Object?>>[];
        if (events.length >= maxBuffered) return;
        events.add({
          'k': kind,
          'step': step,
          'flow_id': flowId,
          'ms': ms,
          'at': now.millisecondsSinceEpoch,
        });
        await _prefs.setString(bufferKey, jsonEncode(events));
    }
  }

  Future<void> _optIn({bool turnGateOn = false}) async {
    if (state != OnboardingFunnelState.optedIn) {
      await _prefs.setString(stateKey, 'in');
    }
    // The setup switch saves the choice before it turns collection on, and
    // an event handed to a gate that is still off is thrown away.
    if (turnGateOn) await _gate.setAnalyticsEnabled(true);
    final events = await _takeBuffer();
    for (final event in events) {
      await _send(
        event['k']! as String,
        event['step']! as String,
        event['flow_id']! as String,
        event['ms']! as int,
      );
    }
  }

  Future<void> _optOut() async {
    await _prefs.setString(stateKey, 'out');
    await _prefs.remove(bufferKey);
  }

  Future<void> _expireIfStale() async {
    if (state != OnboardingFunnelState.unanswered) return;
    if (!_prefs.containsKey(bufferKey)) return;
    final events = await _readBuffer();
    if (events == null || events.isEmpty) {
      await _prefs.remove(bufferKey);
      return;
    }
    final oldest = events
        .map((e) => e['at']! as int)
        .reduce((a, b) => a < b ? a : b);
    final age = _clock().millisecondsSinceEpoch - oldest;
    if (age < maxAge.inMilliseconds) return;
    await _prefs.remove(bufferKey);
    await _prefs.setString(stateKey, 'expired');
  }

  Future<void> _send(String kind, String step, String flowId, int ms) =>
      kind == _viewed
      ? _analytics.stepViewed(step: step, flowId: flowId, msSincePrevious: ms)
      : _analytics.stepCompleted(
          step: step,
          flowId: flowId,
          msSincePrevious: ms,
        );

  /// The waiting events, with the list already deleted, so a crash while
  /// sending cannot send them twice. A list that does not check out is
  /// deleted and gives nothing.
  Future<List<Map<String, Object?>>> _takeBuffer() async {
    final events = await _readBuffer();
    await _prefs.remove(bufferKey);
    return events ?? const [];
  }

  /// The stored list, or null when there is none or it is not exactly what
  /// this class writes. A corrupt list is deleted.
  Future<List<Map<String, Object?>>?> _readBuffer() async {
    final raw = _prefs.getString(bufferKey);
    if (raw == null) return null;
    final events = _decode(raw);
    if (events == null) await _prefs.remove(bufferKey);
    return events;
  }

  List<Map<String, Object?>>? _decode(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! List || decoded.length > maxBuffered) return null;
    final events = <Map<String, Object?>>[];
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) return null;
      if (row.length != _fields.length || !row.keys.every(_fields.contains)) {
        return null;
      }
      final kind = row['k'];
      final step = row['step'];
      final flowId = row['flow_id'];
      final ms = row['ms'];
      final at = row['at'];
      if (kind != _viewed && kind != _completed) return null;
      if (step is! String || !_stepIds.contains(step)) return null;
      if (flowId is! String || !_flowIdPattern.hasMatch(flowId)) return null;
      if (ms is! int || ms < 0 || at is! int) return null;
      events.add(Map<String, Object?>.from(row));
    }
    return events;
  }

  /// One thing at a time, in the order asked, so two events in a row cannot
  /// read the same list and lose one. A failure never reaches the caller.
  Future<void> _enqueue(Future<void> Function() job) {
    final next = _queue.then((_) async {
      try {
        await job();
      } on Object {
        // Counting steps must never get in the way of setting up.
      }
    });
    _queue = next;
    return next;
  }
}
