import 'dart:async';
import 'dart:convert';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the relay's copy of this handset's Live Activity tokens current.
///
/// Two kinds go up, both on `POST /relay/v1/devices/{id}/tokens`:
///
/// * `la_start` is the push-to-start token. One per install. It is what lets
///   the relay put a card on the lock screen with the app not running.
/// * `la_update` belongs to one card. It carries the incident id, and it is
///   what lets the relay change that card's state or end it.
///
/// Runs on every launch and again whenever iOS hands out a new token. The
/// token last accepted by the relay is kept on disk, so a launch that changed
/// nothing does not spend a request. A failed upload is dropped and retried on
/// the next launch or the next rotation, the same way `DeviceTokenRegistry`
/// handles the push token.
final class LiveActivityTokenRegistry {
  LiveActivityTokenRegistry({
    required this.prefs,
    required this.api,
    required this.identity,
    required this.host,
  });

  /// What the last accepted upload of each kind looked like, as JSON:
  /// `{"la_start": "...", "la_update:inc_1:activity_1": "..."}`.
  static const acceptedKey = 'relay_activity_tokens';

  final SharedPreferences prefs;
  final ApiClient api;
  final DeviceIdentityStore identity;
  final AlarmHost host;

  StreamSubscription<ActivityToken>? _rotations;

  /// True after a push-to-start token has actually arrived. False is what the
  /// diagnostics screen shows as "not ready".
  bool pushToStartReady = false;

  /// Uploads whatever was captured before Dart was listening, then watches for
  /// rotations.
  Future<void> start() async {
    await _rotations?.cancel();
    _rotations = host.activityTokens.listen(
      (token) => unawaited(upload(token)),
    );
    pushToStartReady = await host.pushToStartReady();
    if (!pushToStartReady) {
      _log('push_to_start_not_ready retry=next_launch');
    }
    for (final token in await host.takePendingTokens()) {
      await upload(token);
    }
  }

  Future<void> stop() async {
    await _rotations?.cancel();
    _rotations = null;
  }

  /// Sends one token. Returns true when a call was actually made.
  Future<bool> upload(ActivityToken token) async {
    final device = await identity.readOrCreate();
    final deviceToken = device.deviceToken;
    if (deviceToken == null) {
      // Not registered yet. The next launch registers first and then gets here.
      _log('activity_token_deferred kind=${token.kind} reason=unregistered');
      return false;
    }

    final slot = _slot(token);
    final accepted = _readAccepted();
    if (accepted[slot] == token.token) return false;

    try {
      await api.uploadActivityToken(
        deviceId: device.deviceId,
        deviceToken: deviceToken,
        kind: token.kind,
        token: token.token,
        incidentId: token.incidentId,
        activityId: token.activityId,
      );
    } on Object catch (_) {
      _log('activity_token_failed kind=${token.kind}');
      return false;
    }

    accepted[slot] = token.token;
    await prefs.setString(acceptedKey, jsonEncode(accepted));
    if (token.kind == ActivityTokenKind.pushToStart) pushToStartReady = true;
    _log(
      'activity_token_uploaded kind=${token.kind} '
      'incident_id=${token.incidentId ?? "-"}',
    );
    return true;
  }

  /// Drops the record of every `la_update` token for [incidentId], so a card
  /// started again for the same incident uploads its new token instead of
  /// being skipped as unchanged.
  Future<void> forget(String incidentId) async {
    final accepted = _readAccepted()
      ..removeWhere(
        (key, _) =>
            key == '${ActivityTokenKind.update}:$incidentId' ||
            key.startsWith('${ActivityTokenKind.update}:$incidentId:'),
      );
    await prefs.setString(acceptedKey, jsonEncode(accepted));
  }

  /// One slot per thing that can rotate: the install for `la_start`, and each
  /// activity for `la_update`.
  static String _slot(ActivityToken token) =>
      token.kind != ActivityTokenKind.update
      ? token.kind
      : '${token.kind}:${token.incidentId}:${token.activityId}';

  Map<String, String> _readAccepted() {
    final raw = prefs.getString(acceptedKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is String) entry.key: entry.value as String,
      };
    } on FormatException {
      return {};
    }
  }

  void _log(String message) => debugPrint('CritAlarmActivity: $message');
}

/// The two values the relay accepts for `kind`.
abstract final class ActivityTokenKind {
  /// One per install. Starts a card with no app running.
  static const pushToStart = 'la_start';

  /// One per card. Updates or ends that card.
  static const update = 'la_update';
}
