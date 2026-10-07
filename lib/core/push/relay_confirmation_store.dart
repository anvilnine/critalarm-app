import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the last call to the relay about this handset's push token ended.
enum RelayAttemptOutcome {
  /// The relay took the token.
  accepted,

  /// The relay answered and said no: a 4xx other than a timeout.
  refused,

  /// No answer, or a 5xx. Says nothing about whether the relay would accept
  /// the token.
  failed;

  static RelayAttemptOutcome? fromName(String? name) {
    for (final outcome in values) {
      if (outcome.name == name) return outcome;
    }
    return null;
  }
}

/// What a confirmation was about: this handset's device id, the relay it
/// talked to, and the token it sent.
///
/// A record only counts while all three still match. After a sign out (new
/// device id), a switch of server (new relay) or a rotated token, "the relay
/// accepted it at 09:00" says nothing about what the relay holds now.
///
/// The token is kept as a SHA-256 hash, so it is not written to a new place.
@immutable
class RelayConfirmationScope {
  const RelayConfirmationScope({
    required this.deviceId,
    required this.relay,
    required this.tokenHash,
  });

  factory RelayConfirmationScope.of({
    required String deviceId,
    required String relay,
    required String token,
  }) => RelayConfirmationScope(
    deviceId: deviceId,
    relay: relay,
    tokenHash: sha256.convert(token.codeUnits).toString(),
  );

  /// What a registry built with no scope reader uses. Only tests do that.
  static const unscoped = RelayConfirmationScope(
    deviceId: '',
    relay: '',
    tokenHash: '',
  );

  final String deviceId;
  final String relay;
  final String tokenHash;

  /// Joined with a separator no device id, URL or hex string contains.
  String get encoded => [deviceId, relay, tokenHash].join('\n');

  @override
  bool operator ==(Object other) =>
      other is RelayConfirmationScope && other.encoded == encoded;

  @override
  int get hashCode => encoded.hashCode;
}

/// What the phone remembers about its conversation with the relay over the
/// push token: when it was last accepted, how the last send ended, and which
/// device, relay and token each of those was about.
///
/// `DeviceTokenRegistry` writes it after every call it makes. Anything that
/// wants to say whether the relay holds a good token reads it, and always
/// through a scope: a record for another scope reads as absent.
class RelayConfirmationStore {
  RelayConfirmationStore(SharedPreferences prefs) : _prefs = prefs;

  static const confirmedAtKey = 'relay_push_confirmed_at_ms';
  static const confirmedScopeKey = 'relay_push_confirmed_scope';
  static const attemptAtKey = 'relay_push_attempt_at_ms';
  static const attemptScopeKey = 'relay_push_attempt_scope';
  static const outcomeKey = 'relay_push_attempt_outcome';

  /// Every key this store owns, for anything that has to forget them.
  static const List<String> keys = [
    confirmedAtKey,
    confirmedScopeKey,
    attemptAtKey,
    attemptScopeKey,
    outcomeKey,
  ];

  final SharedPreferences _prefs;

  /// When the relay last accepted the token for [scope]. Null if it never
  /// has, or the last acceptance was for another device, relay or token.
  DateTime? confirmedAtFor(RelayConfirmationScope scope) =>
      _prefs.getString(confirmedScopeKey) == scope.encoded
      ? _read(confirmedAtKey)
      : null;

  /// How the last send for [scope] ended. Null before the first one, and when
  /// the last send was about another scope.
  RelayAttemptOutcome? lastOutcomeFor(RelayConfirmationScope scope) =>
      _prefs.getString(attemptScopeKey) == scope.encoded
      ? RelayAttemptOutcome.fromName(_prefs.getString(outcomeKey))
      : null;

  /// When the phone last sent a token, whatever it was and however it ended.
  DateTime? get lastAttemptAt => _read(attemptAtKey);

  Future<void> record(
    DateTime at,
    RelayAttemptOutcome outcome,
    RelayConfirmationScope scope,
  ) async {
    final ms = at.toUtc().millisecondsSinceEpoch;
    await _prefs.setInt(attemptAtKey, ms);
    await _prefs.setString(attemptScopeKey, scope.encoded);
    await _prefs.setString(outcomeKey, outcome.name);
    if (outcome == RelayAttemptOutcome.accepted) {
      await _prefs.setInt(confirmedAtKey, ms);
      await _prefs.setString(confirmedScopeKey, scope.encoded);
    }
  }

  /// Forgets everything, as a sign out does.
  Future<void> clear() async {
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  DateTime? _read(String key) {
    final ms = _prefs.getInt(key);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
}
