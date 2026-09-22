import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/settings/domain/entities/storage_settings.dart';

/// Removes alarms the user asked the phone to stop keeping.
///
/// Runs on launch and on resume. It is the only thing in the app that deletes
/// a local row: a plan change never does, because the rows are the user's
/// copy and not the server's (api.md §4.2). With "Keep critical alarms
/// forever" on, a P5 incident and its messages stay whatever the setting is.
class AutoDeleteHistoryUsecase {
  const AutoDeleteHistoryUsecase(this._store, this._settings);

  final LocalStore? _store;
  final StorageSettings Function() _settings;

  /// How many incidents were removed.
  Future<int> call({DateTime? now}) async {
    final store = _store;
    if (store == null) return 0;

    final settings = _settings();
    final days = settings.retention.days;
    if (days == null) return 0;

    final cutoff = (now ?? DateTime.now()).subtract(Duration(days: days));
    final keepP5 = settings.keepCriticalForever;
    final removed = await store.incidents.deleteOlderThan(
      cutoff,
      keepP5: keepP5,
    );
    await store.messages.deleteOlderThan(cutoff, keepP5: keepP5);
    return removed;
  }
}
