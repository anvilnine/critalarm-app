import 'dart:async';

import 'package:critalarm/core/alarm/quiet_hours.dart';
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

  /// Puts an alarm [delaySeconds] out for [incidentId], replacing any alarm
  /// already set for it. Answers false when it did not get scheduled, which
  /// is what the onboarding test reads to know the ring is not coming.
  ///
  /// The delay crosses the channel because the UI counts it down. When the two
  /// disagreed, the phone rang 27 seconds before the screen said it would.
  ///
  /// [handOverToStatusCard] false means this alarm has no incident behind it,
  /// which is the onboarding test alarm. It rides the alarm all the way to the
  /// Stop button the notification shows, so that button leaves no card: an
  /// acked card is ongoing, so it cannot be swiped away, and its Done button
  /// would close an incident that does not exist.
  Future<bool> scheduleAlarm({
    required String incidentId,
    required String topic,
    required String server,
    required String title,
    String? sound,
    String? body,
    int delaySeconds = 3,
    bool handOverToStatusCard = true,
  }) async =>
      await _invoke<bool>('scheduleAlarm', {
        'incident_id': incidentId,
        'topic': topic,
        'server': server,
        'title': title,
        'sound': ?sound,
        'body': ?body,
        'delay_seconds': delaySeconds,
        'hand_over_to_status_card': handOverToStatusCard,
      }) ??
      false;

  /// Stops the alarm for [incidentId] and says what should be left behind.
  ///
  /// [handOverToStatusCard] true means the user acknowledged: the incident is
  /// still open, so Android replaces the ringing card with the acked one that
  /// carries the Done button. False means the incident is over, or was never
  /// real, so both cards come down and nothing replaces them. Only the caller
  /// knows which of the two it is, and getting it wrong leaves an ongoing card
  /// on an incident nobody can close.
  ///
  /// [title] and [body] are what the screen was showing. The acked card is
  /// built natively, with no engine and no network, so without them it reads
  /// "Critical incident" while the page behind it says what happened.
  Future<bool> cancelAlarm(
    String incidentId, {
    required bool handOverToStatusCard,
    String? title,
    String? body,
  }) async =>
      await _invoke<bool>('cancelAlarm', {
        'incident_id': incidentId,
        'hand_over_to_status_card': handOverToStatusCard,
        'title': ?title,
        'body': ?body,
      }) ??
      false;

  /// Stop whatever is ringing on this device, whichever incident it belongs to.
  ///
  /// [cancelAlarm] needs an id, and an id can be wrong: the server can ring an
  /// incident the app thinks is already acknowledged, and then nothing in the
  /// app's bookkeeping matches the sound coming out of the speaker. The person
  /// pressing Stop means the noise, not a row in a table, so this asks for
  /// exactly that. Answers false where the platform has no such idea.
  Future<bool> stopRinging() async =>
      await _invoke<bool>('stopRinging') ?? false;

  /// Tells the native side the user has acknowledged [incidentId], so a
  /// `repeat` push for it does not ring again while the ack is still on its
  /// way to the server. iOS keeps the set; Android already drops those
  /// repeats on its own and has no handler for this.
  Future<void> markAcked(String incidentId) async =>
      _invoke<void>('markAcked', {'incident_id': incidentId});

  /// Silences the alarm for [incidentId] and asks the phone to ring again for
  /// the same incident at `now + repeat_interval_s`.
  ///
  /// This is what Stop, a swipe and Back all do. The incident stays open, the
  /// server keeps repeating, and only "I'm up" ends the loop. Answers how many
  /// seconds until that next ring, or null when the native side decided not to
  /// re-arm: past `ring_until`, already acked here, the topic's critical
  /// switch off, or quiet hours holding.
  Future<int?> rearmAlarm(String incidentId) async =>
      _invoke<int>('rearmAlarm', {'incident_id': incidentId});

  /// Drops a pending re-arm for [incidentId] with no other side effect. Used
  /// when the incident is acknowledged, closed or expired somewhere else.
  Future<void> cancelRearm(String incidentId) async =>
      _invoke<void>('cancelRearm', {'incident_id': incidentId});

  /// Whether an alarm is ringing on this device right now. Android answers
  /// from its alarm service, iOS from AlarmKit (false before iOS 26). No
  /// answer reads as not ringing, so nothing waits on a platform that cannot
  /// tell.
  Future<bool> isRinging() async => await _invoke<bool>('isRinging') ?? false;

  /// Writes the open incident ids into the app group. The notification
  /// delegate reads them to know while an alarm is under way, so it can keep
  /// other banners off. Off iOS there is no handler and the call is a no-op.
  Future<void> setOpenIncidents(List<String> incidentIds) async =>
      _invoke<void>('setOpenIncidents', {'incident_ids': incidentIds});

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
      (await _invoke<List<Object?>>(
        'showingIncidentIds',
      ))?.whereType<String>().toList() ??
      const [];

  /// Tokens captured before Dart was listening, taken once and cleared.
  Future<List<ActivityToken>> takePendingTokens() async {
    final raw = await _invoke<List<Object?>>('takePendingActivityTokens');
    if (raw == null) return const [];
    return raw.map(ActivityToken.fromMap).whereType<ActivityToken>().toList();
  }

  /// False when iOS has not handed out a push-to-start token yet. Seen in the
  /// field on iOS 26.5 and shown as "not ready" on the diagnostics screen.
  Future<bool> pushToStartReady() async =>
      await _invoke<bool>('pushToStartReady') ?? false;

  /// Copies the quiet hours window into the App Group the notification
  /// extension reads. The extension is a separate process with its own
  /// container, so it cannot see the app's preferences and needs its own copy.
  Future<void> publishQuietHours(QuietHours window) async =>
      _invoke<void>('publishQuietHours', {
        'enabled': window.isEnabled,
        'start_minutes': window.startMinutes,
        'end_minutes': window.endMinutes,
        'critical_rings': window.criticalRingsThrough,
      });

  /// Copies the text of an incident the app just loaded into the App Group
  /// the notification extension reads.
  ///
  /// Hosted mode strips the text out of the push, so the extension fetches it
  /// with `GET /v1/incidents/{id}`. When the first push was handled in the
  /// foreground, the app already has that text, and this hands it over so the
  /// repeats that follow cost no server call at all.
  Future<void> cacheIncidentContent({
    required String incidentId,
    required String title,
    required String body,
    List<String> tags = const [],
    String? click,
    String? topic,
    int? lastMessageAt,
  }) async => _invoke<void>('cacheIncidentContent', {
    'incident_id': incidentId,
    'title': title,
    'body': body,
    'tags': tags,
    'click': ?click,
    'topic': ?topic,
    'last_message_at': ?lastMessageAt,
  });

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
