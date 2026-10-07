import 'package:critalarm/features/reliability/domain/os_version_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsOsVersionStore implements OsVersionStore {
  SharedPrefsOsVersionStore(this._prefs);

  static const majorKey = 'reliability_os_major';
  static const changedAtKey = 'reliability_os_changed_at_ms';

  final SharedPreferences _prefs;

  @override
  OsVersionRecord read() {
    final changedMs = _prefs.getInt(changedAtKey);
    return OsVersionRecord(
      major: _prefs.getInt(majorKey),
      changedAt: changedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(changedMs, isUtc: true),
    );
  }

  @override
  Future<void> write(OsVersionRecord record) async {
    final major = record.major;
    if (major == null) {
      await _prefs.remove(majorKey);
    } else {
      await _prefs.setInt(majorKey, major);
    }
    final changedAt = record.changedAt;
    if (changedAt == null) {
      await _prefs.remove(changedAtKey);
    } else {
      await _prefs.setInt(
        changedAtKey,
        changedAt.toUtc().millisecondsSinceEpoch,
      );
    }
  }
}
