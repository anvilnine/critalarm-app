import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class SharedPrefsApiSessionStore implements ApiSessionStore {
  SharedPrefsApiSessionStore(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'api_session';

  @override
  Future<ApiSession?> read() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 4) return null;
    return ApiSession(
      baseUri: Uri.parse(parts[0]),
      relayUri: Uri.parse(parts[1]),
      mode: ServerMode.fromWireValue(parts[2]),
      managementCredential: parts[3],
    );
  }

  @override
  Future<void> write(ApiSession session) async {
    await _prefs.setString(
      _key,
      [
        session.baseUri,
        session.relayUri,
        session.mode.wireValue,
        session.managementCredential,
      ].join('|'),
    );
  }

  @override
  Future<void> clear() async => _prefs.remove(_key);
}
