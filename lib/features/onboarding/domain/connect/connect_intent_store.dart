import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A connect the user asked for that has not landed yet.
///
/// It holds the address of the server and when to try next. It never holds a
/// token: the credential only exists once the connect has worked, and then
/// it is saved as the connection itself.
@immutable
class ConnectIntent {
  const ConnectIntent({
    required this.serverUrl,
    this.attempts = 0,
    this.nextAttemptAtMs = 0,
  });

  final String serverUrl;

  /// Tries that failed in a way worth trying again.
  final int attempts;

  /// The timer leaves the intent alone until this moment.
  final int nextAttemptAtMs;

  ConnectIntent copyWith({int? attempts, int? nextAttemptAtMs}) =>
      ConnectIntent(
        serverUrl: serverUrl,
        attempts: attempts ?? this.attempts,
        nextAttemptAtMs: nextAttemptAtMs ?? this.nextAttemptAtMs,
      );

  Map<String, Object> toJson() => {
    'server_url': serverUrl,
    'attempts': attempts,
    'next_attempt_at_ms': nextAttemptAtMs,
  };

  static ConnectIntent? fromJson(Object? json) {
    if (json is! Map) return null;
    final serverUrl = json['server_url'];
    if (serverUrl is! String || serverUrl.isEmpty) return null;
    final attempts = json['attempts'];
    final nextAttemptAtMs = json['next_attempt_at_ms'];
    return ConnectIntent(
      serverUrl: serverUrl,
      attempts: attempts is int ? attempts : 0,
      nextAttemptAtMs: nextAttemptAtMs is int ? nextAttemptAtMs : 0,
    );
  }
}

/// Keeps the pending connect on disk, so it survives the app being closed.
///
/// It has its own key. It is not part of the setup draft, and it is not a
/// saved connection: Home reads a saved connection as "a server exists".
final class ConnectIntentStore {
  const ConnectIntentStore(this._prefs);

  static const storageKey = 'connect_intent_v1';

  final SharedPreferences _prefs;

  ConnectIntent? read() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ConnectIntent.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> save(ConnectIntent intent) =>
      _prefs.setString(storageKey, jsonEncode(intent.toJson()));

  Future<void> clear() => _prefs.remove(storageKey);
}
