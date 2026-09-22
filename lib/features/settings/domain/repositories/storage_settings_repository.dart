import 'package:critalarm/features/settings/domain/entities/storage_settings.dart';

/// Where the two Storage rows live.
abstract interface class StorageSettingsRepository {
  StorageSettings read();

  Future<void> setRetention(HistoryRetention retention);

  Future<void> setKeepCriticalForever({required bool keep});
}
