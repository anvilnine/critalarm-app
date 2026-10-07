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

/// What the phone remembers about its conversation with the relay over the
/// push token: when it was last accepted, when it was last sent, and how the
/// last send ended.
///
/// `DeviceTokenRegistry` writes it after every call it makes. Anything that
/// wants to say whether the relay holds a good token reads it.
final class RelayConfirmationStore {
  RelayConfirmationStore(this._prefs);

  static const confirmedAtKey = 'relay_push_confirmed_at_ms';
  static const attemptAtKey = 'relay_push_attempt_at_ms';
  static const outcomeKey = 'relay_push_attempt_outcome';

  final SharedPreferences _prefs;

  /// When the relay last accepted the token. Null if it never has.
  DateTime? get confirmedAt => _read(confirmedAtKey);

  /// When the phone last sent the token, accepted or not.
  DateTime? get lastAttemptAt => _read(attemptAtKey);

  /// How the last send ended. Null before the first one.
  RelayAttemptOutcome? get lastOutcome =>
      RelayAttemptOutcome.fromName(_prefs.getString(outcomeKey));

  Future<void> record(DateTime at, RelayAttemptOutcome outcome) async {
    final ms = at.toUtc().millisecondsSinceEpoch;
    await _prefs.setInt(attemptAtKey, ms);
    await _prefs.setString(outcomeKey, outcome.name);
    if (outcome == RelayAttemptOutcome.accepted) {
      await _prefs.setInt(confirmedAtKey, ms);
    }
  }

  DateTime? _read(String key) {
    final ms = _prefs.getInt(key);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
}
