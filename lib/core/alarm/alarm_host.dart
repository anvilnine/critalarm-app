import 'dart:async';

import 'package:flutter/services.dart';

/// Whether the user has let the app set alarms.
enum AlarmAuthorization {
  notDetermined,
  denied,
  authorized,

  /// The OS is older than iOS 26, or this is not iOS at all. Nothing to ask
  /// for and nothing to fix in Settings.
  unsupported;

  static AlarmAuthorization fromName(String? name) => switch (name) {
    'authorized' => AlarmAuthorization.authorized,
    'denied' => AlarmAuthorization.denied,
    'notDetermined' => AlarmAuthorization.notDetermined,
    _ => AlarmAuthorization.unsupported,
  };

  /// A critical topic needs a real alarm. Without one the push still arrives,
  /// but only as a notification, so the toggle is turned off and explained.
  bool get canRingAnAlarm => this == AlarmAuthorization.authorized;
}

/// One Live Activity token on its way to the relay.
class ActivityToken {
  const ActivityToken({
    required this.kind,
    required this.token,
    this.incidentId,
    this.activityId,
  });

  /// `la_start` (one per install, lets the relay start a card with no app
  /// running) or `la_update` (one per card, lets the relay update or end it).
  final String kind;
  final String token;

  /// Set on `la_update` only: which card the token belongs to.
  final String? incidentId;
  final String? activityId;

  static ActivityToken? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'];
    final token = raw['token'];
    if (kind is! String || kind.isEmpty) return null;
    if (token is! String || token.isEmpty) return null;
    final incidentId = raw['incident_id'];
    return ActivityToken(
      kind: kind,
      token: token,
      activityId: raw['activity_id'] as String?,
      incidentId: incidentId is String && incidentId.isNotEmpty
          ? incidentId
          : null,
    );
  }

  Map<String, Object?> toJson() => {
    'kind': kind,
    'token': token,
    'incident_id': ?incidentId,
    'activity_id': ?activityId,
  };
}

/// The native half of the alarm and the acknowledge card.
///
/// `AppDelegate.swift` owns AlarmKit and ActivityKit. Dart owns the decision
/// to ring, the relay calls and the retry loop. Everything crossing between
/// goes through here.
///
/// Off iOS every call is a no-op: the channel has no handler, the platform
/// answers [MissingPluginException], and this hands back a safe default.
final class AlarmHost {
  AlarmHost([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handle);
  }

  static const channelName = 'app.critalarm/alarm';

  final MethodChannel _channel;
  final _tokens = StreamController<ActivityToken>.broadcast();
  final _scheduled = StreamController<String>.broadcast();

  /// Tokens captured while the app is running. Tokens captured before Dart was
  /// listening come from [takePendingTokens] instead.
  Stream<ActivityToken> get activityTokens => _tokens.stream;

  /// Incident ids the native side scheduled an alarm for. A background push
  /// schedules with no Dart involved, and this is how the in-app rule that
  /// blocks a second card hears about it.
  Stream<String> get alarmsScheduled => _scheduled.stream;

  Future<AlarmAuthorization> authorizationStatus() async =>
      AlarmAuthorization.fromName(await _invoke<String>('authorizationStatus'));

  /// Shows the system prompt. Answers with whatever the user chose.
  Future<AlarmAuthorization> requestAuthorization() async =>
      AlarmAuthorization.fromName(
        await _invoke<String>('requestAuthorization'),
      );

  /// Puts an alarm a few seconds out for [incidentId], replacing any alarm
  /// already set for it. Answers false when it did not get scheduled.
  Future<bool> scheduleAlarm({
    required String incidentId,
    required String topic,
    required String server,
    required String title,
    String? sound,
  }) async =>
      await _invoke<bool>('scheduleAlarm', {
        'incident_id': incidentId,
        'topic': topic,
        'server': server,
        'title': title,
        'sound': ?sound,
      }) ??
      false;

  /// The incident closed or expired. Stops the alarm and ends the card.
  Future<bool> cancelAlarm(String incidentId) async =>
      await _invoke<bool>('cancelAlarm', {'incident_id': incidentId}) ?? false;

  /// Onboarding uses this once so the Allow prompt happens before the relay
  /// ever tries a remote start.
  Future<bool> startLocalActivity({
    required String incidentId,
    required String topic,
    required String server,
    required String title,
    String state = 'open',
  }) async =>
      await _invoke<bool>('startLocalActivity', {
        'incident_id': incidentId,
        'topic': topic,
        'server': server,
        'title': title,
        'state': state,
      }) ??
      false;

  Future<bool> endActivity(
    String incidentId, {
    String state = 'closed',
  }) async =>
      await _invoke<bool>('endActivity', {
        'incident_id': incidentId,
        'state': state,
      }) ??
      false;

  /// Incident ids with a card on the lock screen right now.
  Future<List<String>> showingIncidentIds() async =>
      (await _invoke<List<Object?>>('showingIncidentIds'))
          ?.whereType<String>()
          .toList() ??
      const [];

  /// Tokens captured before Dart was listening, taken once and cleared.
  Future<List<ActivityToken>> takePendingTokens() async {
    final raw = await _invoke<List<Object?>>('takePendingActivityTokens');
    if (raw == null) return const [];
    return raw
        .map(ActivityToken.fromMap)
        .whereType<ActivityToken>()
        .toList();
  }

  /// False when iOS has not handed out a push-to-start token yet. Seen in the
  /// field on iOS 26.5 and shown as "not ready" on the diagnostics screen.
  Future<bool> pushToStartReady() async =>
      await _invoke<bool>('pushToStartReady') ?? false;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _handle(MethodCall call) async {
    switch (call.method) {
      case 'onActivityToken':
        final token = ActivityToken.fromMap(call.arguments);
        if (token != null) _tokens.add(token);
      case 'onAlarmScheduled':
        final id = call.arguments as String?;
        if (id != null && id.isNotEmpty) _scheduled.add(id);
    }
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _tokens.close();
    await _scheduled.close();
  }
}
