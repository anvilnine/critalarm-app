import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/domain/entities/storage_settings.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

// The value a Settings row shows at its trailing end. Each one reads state
// the screen already holds, never a new read, and returns a `LocaleKeys` key
// or null when the value is not known. A row with no value shows only its
// arrow.

/// Where this phone gets its pages from, or null before the saved server has
/// been read.
String? settingsServerValueKey({
  required SettingsStatus status,
  required bool isConnected,
  required ServerMode? mode,
}) {
  if (status != SettingsStatus.success) return null;
  if (!isConnected) return LocaleKeys.settings_server_status_disconnected;
  return switch (mode) {
    null => null,
    ServerMode.selfhosted => LocaleKeys.settings_server_self_hosted,
    ServerMode.relay => LocaleKeys.settings_server_relay,
    ServerMode.hosted => LocaleKeys.settings_server_hosted,
  };
}

/// How long the phone keeps alarms.
String settingsStorageValueKey(HistoryRetention retention) =>
    switch (retention) {
      HistoryRetention.never => LocaleKeys.settings_card_value_keep_all,
      HistoryRetention.oneMonth => LocaleKeys.settings_storage_delete_1m,
      HistoryRetention.threeMonths => LocaleKeys.settings_storage_delete_3m,
      HistoryRetention.oneYear => LocaleKeys.settings_storage_delete_1y,
    };

/// The theme the user picked.
String settingsThemeValueKey(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => LocaleKeys.settings_theme_system,
  AppThemeMode.light => LocaleKeys.settings_theme_light,
  AppThemeMode.dark => LocaleKeys.settings_theme_dark,
};
