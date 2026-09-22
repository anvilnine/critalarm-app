import 'package:critalarm/features/settings/domain/entities/storage_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/storage_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Storage rows, kept in preferences.
///
/// Two small values, so there is no table for them. The rows they act on live
/// in `critalarm.db`, which this never touches: auto-delete reads these and
/// then asks the store.
class SharedPrefsStorageSettingsRepository
    implements StorageSettingsRepository {
  const SharedPrefsStorageSettingsRepository(this._prefs);

  static const retentionKey = 'history_retention';
  static const keepCriticalKey = 'history_keep_critical';

  final SharedPreferences _prefs;

  @override
  StorageSettings read() => StorageSettings(
    retention: HistoryRetention.byName(_prefs.getString(retentionKey)),
    keepCriticalForever: _prefs.getBool(keepCriticalKey) ?? true,
  );

  @override
  Future<void> setRetention(HistoryRetention retention) async {
    await _prefs.setString(retentionKey, retention.name);
  }

  @override
  Future<void> setKeepCriticalForever({required bool keep}) async {
    await _prefs.setBool(keepCriticalKey, keep);
  }
}
