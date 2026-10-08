import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/domain/entities/storage_settings.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/settings/presentation/settings_row_values.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('settingsServerValueKey', () {
    String? key(
      SettingsStatus status, {
      required bool connected,
      ServerMode? mode,
    }) => settingsServerValueKey(
      status: status,
      isConnected: connected,
      mode: mode,
    );

    test('says nothing before the saved server has been read', () {
      expect(key(SettingsStatus.initial, connected: false), isNull);
      expect(
        key(SettingsStatus.loading, connected: true, mode: ServerMode.hosted),
        isNull,
      );
    });

    test('names the server once it is read', () {
      expect(
        key(SettingsStatus.success, connected: true, mode: ServerMode.hosted),
        LocaleKeys.settings_server_hosted,
      );
      expect(
        key(
          SettingsStatus.success,
          connected: true,
          mode: ServerMode.selfhosted,
        ),
        LocaleKeys.settings_server_self_hosted,
      );
      expect(
        key(SettingsStatus.success, connected: true, mode: ServerMode.relay),
        LocaleKeys.settings_server_relay,
      );
    });

    test('no server is said plainly, and an unknown mode says nothing', () {
      expect(
        key(SettingsStatus.success, connected: false),
        LocaleKeys.settings_server_status_disconnected,
      );
      expect(key(SettingsStatus.success, connected: true), isNull);
    });
  });

  test('settingsStorageValueKey covers every retention', () {
    expect(
      {
        for (final r in HistoryRetention.values) r: settingsStorageValueKey(r),
      },
      {
        HistoryRetention.never: LocaleKeys.settings_card_value_keep_all,
        HistoryRetention.oneMonth: LocaleKeys.settings_storage_delete_1m,
        HistoryRetention.threeMonths: LocaleKeys.settings_storage_delete_3m,
        HistoryRetention.oneYear: LocaleKeys.settings_storage_delete_1y,
      },
    );
  });

  test('settingsThemeValueKey covers every theme', () {
    expect(
      {
        for (final m in AppThemeMode.values) m: settingsThemeValueKey(m),
      },
      {
        AppThemeMode.system: LocaleKeys.settings_theme_system,
        AppThemeMode.light: LocaleKeys.settings_theme_light,
        AppThemeMode.dark: LocaleKeys.settings_theme_dark,
      },
    );
  });
}
