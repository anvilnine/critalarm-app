import 'package:critalarm/core/account/account_tag.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The own sounds lock flag in the app's preferences, and the account it
/// was written for.
///
/// Two keys:
///
/// - `alarm_sound_own_locked`: the boolean native code reads
///   ([ownSoundsLockedKey]). Native reads this key and nothing else, so it
///   stays a plain boolean.
/// - `alarm_sound_own_locked_for`: the tag of the account the boolean was
///   written for ([accountTagFor]). Only Dart reads it.
///
/// The boolean says something about one account's plan. Preferences
/// outlive a sign-out and travel to another phone in a backup, so Dart
/// trusts the boolean only while the tag next to it is the one of the
/// account this phone is on. [keepOnlyFor] takes away a boolean written
/// for another account, and a boolean nobody trusts reads as never
/// written, which the writer answers by writing on its next sure answer.
///
/// No flag is "not locked" to native. That never ends with no sound: the
/// saved choice rings, and native still falls back to a bundled sound when
/// the file is not there.
class OwnSoundLockFlag {
  OwnSoundLockFlag(this._prefs);

  static const String accountKey = '${ownSoundsLockedKey}_for';

  final SharedPreferences _prefs;

  /// The tag of the account this phone is on, as [keepOnlyFor] was last
  /// told. Null until then, and while the phone has no account.
  String? _accountTag;

  String? get _writtenFor {
    try {
      return _prefs.getString(accountKey);
    } on Object catch (_) {
      return null;
    }
  }

  /// The flag as written for the account this phone is on. Null when it
  /// never was, when it was written for another account or for none, and
  /// when the key holds something that is not a boolean.
  bool? get written {
    if (!noteIsForAccount(noteTag: _writtenFor, accountTag: _accountTag)) {
      return null;
    }
    try {
      return _prefs.getBool(ownSoundsLockedKey);
    } on Object catch (_) {
      return null;
    }
  }

  /// Says which account this phone is on, and takes the flag away when it
  /// was written for another one. True when a flag was taken away, so the
  /// copy the iOS extension reads has to be made again.
  ///
  /// With no account known ([accountTag] null) nothing is taken away: the
  /// flag stays where native reads it, and [written] answers null until an
  /// account is known. A phone that is between two accounts keeps ringing
  /// the way it last did.
  Future<bool> keepOnlyFor(String? accountTag) async {
    _accountTag = accountTag;
    if (accountTag == null) return false;
    if (_writtenFor == accountTag) return false;
    return clear();
  }

  /// Writes the flag for the account this phone is on. Throws when no
  /// account is known: there is nobody to write it for, and the writer
  /// tries again on its next check.
  Future<void> write({required bool locked}) async {
    final tag = _accountTag;
    if (tag == null) throw StateError('No account to write the flag for');
    await _prefs.setBool(ownSoundsLockedKey, locked);
    if (_writtenFor != tag) await _prefs.setString(accountKey, tag);
  }

  /// Takes the flag and its tag away. True when the flag was there.
  Future<bool> clear() async {
    final wasThere = _prefs.containsKey(ownSoundsLockedKey);
    await _prefs.remove(ownSoundsLockedKey);
    await _prefs.remove(accountKey);
    return wasThere;
  }
}
