import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_privacy_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_theme_preference_repository.dart';
import 'package:critalarm/features/settings/domain/entities/app_theme_mode.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPrefsPrivacyRepository Store Logic', () {
    test('privacy toggles are strictly OFF (false) by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsPrivacyRepository(prefs);

      final result = await repository.getPrivacySettings();
      expect(result.isSuccess(), isTrue);

      final settings = result.getOrNull();
      expect(settings, isNotNull);
      expect(
        settings?.analyticsEnabled,
        isFalse,
        reason: 'Analytics collection must be strictly OFF by default',
      );
      expect(
        settings?.crashReportingEnabled,
        isFalse,
        reason: 'Crash reporting collection must be strictly OFF by default',
      );
    });

    test('proves independent persistence of analyticsEnabled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsPrivacyRepository(prefs);

      // Enable analytics only
      final saveResult = await repository.setAnalyticsEnabled(enabled: true);
      expect(saveResult.isSuccess(), isTrue);

      final fetched = (await repository.getPrivacySettings()).getOrNull();
      expect(
        fetched?.analyticsEnabled,
        isTrue,
        reason: 'analyticsEnabled should be persisted as true',
      );
      expect(
        fetched?.crashReportingEnabled,
        isFalse,
        reason:
            'crashReportingEnabled must remain false when analytics is toggled',
      );

      // Toggle analytics back to false
      await repository.setAnalyticsEnabled(enabled: false);
      final fetchedAfterToggle = (await repository.getPrivacySettings())
          .getOrNull();
      expect(fetchedAfterToggle?.analyticsEnabled, isFalse);
      expect(fetchedAfterToggle?.crashReportingEnabled, isFalse);
    });

    test('proves independent persistence of crashReportingEnabled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsPrivacyRepository(prefs);

      // Enable crash reporting only
      final saveResult = await repository.setCrashReportingEnabled(
        enabled: true,
      );
      expect(saveResult.isSuccess(), isTrue);

      final fetched = (await repository.getPrivacySettings()).getOrNull();
      expect(
        fetched?.crashReportingEnabled,
        isTrue,
        reason: 'crashReportingEnabled should be persisted as true',
      );
      expect(
        fetched?.analyticsEnabled,
        isFalse,
        reason:
            'analyticsEnabled must remain false when crash reporting '
            'is toggled',
      );
    });

    test(
      'both flags can be enabled simultaneously and independently',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = SharedPrefsPrivacyRepository(prefs);

        await repository.setAnalyticsEnabled(enabled: true);
        await repository.setCrashReportingEnabled(enabled: true);

        final bothTrue = (await repository.getPrivacySettings()).getOrNull();
        expect(bothTrue?.analyticsEnabled, isTrue);
        expect(bothTrue?.crashReportingEnabled, isTrue);

        // Turn off crash reporting only
        await repository.setCrashReportingEnabled(enabled: false);
        final analyticsStillOn = (await repository.getPrivacySettings())
            .getOrNull();
        expect(analyticsStillOn?.analyticsEnabled, isTrue);
        expect(analyticsStillOn?.crashReportingEnabled, isFalse);
      },
    );
  });

  group('SharedPrefsConnectionRepository Store Logic', () {
    test(
      'getConnection returns Failure.notFound when no connection stored',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = SharedPrefsConnectionRepository(prefs);

        final result = await repository.getConnection();
        expect(result.isError(), isTrue);
      },
    );

    test('proves saveConnection persists serverUrl and adminToken', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsConnectionRepository(prefs);

      const connection = ServerConnection(
        serverUrl: 'https://alerts.critalarm.app',
        adminToken: 'ad_test_secret_token_123',
      );

      final saveResult = await repository.saveConnection(connection);
      expect(saveResult.isSuccess(), isTrue);

      final fetchResult = await repository.getConnection();
      expect(fetchResult.isSuccess(), isTrue);

      final saved = fetchResult.getOrNull();
      expect(saved?.serverUrl, equals('https://alerts.critalarm.app'));
      expect(saved?.adminToken, equals('ad_test_secret_token_123'));
    });

    test('proves clearConnection removes connection (disconnects)', () async {
      SharedPreferences.setMockInitialValues({
        'server_url': 'https://alerts.critalarm.app',
        'admin_token': 'ad_123',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsConnectionRepository(prefs);

      // Verify connection is present initially
      expect((await repository.getConnection()).isSuccess(), isTrue);

      // Disconnect
      final clearResult = await repository.clearConnection();
      expect(clearResult.isSuccess(), isTrue);

      // Verify connection is removed
      final fetchAfterClear = await repository.getConnection();
      expect(fetchAfterClear.isError(), isTrue);
    });

    test('partial/corrupt connection data is treated as not found', () async {
      // Only server_url saved, missing admin_token
      SharedPreferences.setMockInitialValues({
        'server_url': 'https://alerts.critalarm.app',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsConnectionRepository(prefs);

      expect((await repository.getConnection()).isError(), isTrue);

      // Only admin_token saved, missing server_url
      SharedPreferences.setMockInitialValues({
        'admin_token': 'ad_123',
      });
      final prefs2 = await SharedPreferences.getInstance();
      final repository2 = SharedPrefsConnectionRepository(prefs2);

      expect((await repository2.getConnection()).isError(), isTrue);
    });
  });

  group('SettingsCubit Connection Store Integration & isConnected Flag', () {
    test(
      'load() with no connection stored sets isConnected to false',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final connRepo = SharedPrefsConnectionRepository(prefs);
        final privacyRepo = SharedPrefsPrivacyRepository(prefs);

        final cubit = SettingsCubit(
          connectionRepository: connRepo,
          privacyRepository: privacyRepo,
          telemetryGate: const NoopTelemetryGate(),
        );

        await cubit.load();

        expect(
          cubit.state.isConnected,
          isFalse,
          reason: 'isConnected must be false when store has no connection',
        );
        await cubit.close();
      },
    );

    test(
      'load() with saved connection sets isConnected to true with credentials',
      () async {
        SharedPreferences.setMockInitialValues({
          'server_url': 'https://alerts.example.com',
          'admin_token': 'ad_saved_token',
        });
        final prefs = await SharedPreferences.getInstance();
        final connRepo = SharedPrefsConnectionRepository(prefs);
        final privacyRepo = SharedPrefsPrivacyRepository(prefs);

        final cubit = SettingsCubit(
          connectionRepository: connRepo,
          privacyRepository: privacyRepo,
          telemetryGate: const NoopTelemetryGate(),
        );

        await cubit.load();

        expect(cubit.state.isConnected, isTrue);
        expect(cubit.state.serverUrl, 'https://alerts.example.com');
        expect(cubit.state.adminToken, 'ad_saved_token');
        await cubit.close();
      },
    );

    test(
      'saveConnection() updates store and emits isConnected: true',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final connRepo = SharedPrefsConnectionRepository(prefs);
        final privacyRepo = SharedPrefsPrivacyRepository(prefs);

        final cubit = SettingsCubit(
          connectionRepository: connRepo,
          privacyRepository: privacyRepo,
          telemetryGate: const NoopTelemetryGate(),
        );

        await cubit.saveConnection(
          serverUrl: 'https://new-server.org',
          adminToken: 'ad_new_token',
        );

        expect(cubit.state.isConnected, isTrue);
        expect(cubit.state.serverUrl, 'https://new-server.org');
        expect(cubit.state.adminToken, 'ad_new_token');

        // Verify underlying repository
        final savedInStore = (await connRepo.getConnection()).getOrNull();
        expect(savedInStore?.serverUrl, 'https://new-server.org');
        expect(savedInStore?.adminToken, 'ad_new_token');

        await cubit.close();
      },
    );

    test(
      'disconnectServer() clears store and emits isConnected: false',
      () async {
        SharedPreferences.setMockInitialValues({
          'server_url': 'https://old-server.org',
          'admin_token': 'ad_old_token',
        });
        final prefs = await SharedPreferences.getInstance();
        final connRepo = SharedPrefsConnectionRepository(prefs);
        final privacyRepo = SharedPrefsPrivacyRepository(prefs);

        final cubit = SettingsCubit(
          connectionRepository: connRepo,
          privacyRepository: privacyRepo,
          telemetryGate: const NoopTelemetryGate(),
        );

        await cubit.load();
        expect(cubit.state.isConnected, isTrue);

        await cubit.disconnectServer();

        expect(
          cubit.state.isConnected,
          isFalse,
          reason: 'isConnected must be false after disconnectServer()',
        );
        expect(cubit.state.serverUrl, isEmpty);
        expect(cubit.state.adminToken, isEmpty);

        // Verify cleared in underlying repository
        final fetchAfterDisconnect = await connRepo.getConnection();
        expect(fetchAfterDisconnect.isError(), isTrue);

        await cubit.close();
      },
    );

    test(
      'load(forceDisconnected: true) emits isConnected: false directly',
      () async {
        SharedPreferences.setMockInitialValues({
          'server_url': 'https://alerts.critalarm.app',
          'admin_token': 'ad_123',
        });
        final prefs = await SharedPreferences.getInstance();
        final connRepo = SharedPrefsConnectionRepository(prefs);
        final privacyRepo = SharedPrefsPrivacyRepository(prefs);

        final cubit = SettingsCubit(
          connectionRepository: connRepo,
          privacyRepository: privacyRepo,
          telemetryGate: const NoopTelemetryGate(),
        );

        await cubit.load(forceDisconnected: true);

        expect(cubit.state.isConnected, isFalse);
        expect(cubit.state.serverUrl, isEmpty);
        await cubit.close();
      },
    );
  });

  group('SharedPrefsThemePreferenceRepository Store Logic', () {
    test(
      'theme mode defaults to AppThemeMode.system when unconfigured',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = SharedPrefsThemePreferenceRepository(prefs);

        final result = await repository.getThemeMode();
        expect(result.isSuccess(), isTrue);
        expect(result.getOrNull(), equals(AppThemeMode.system));
      },
    );

    test('proves theme mode store saves and updates theme settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsThemePreferenceRepository(prefs);

      // Save dark mode
      final darkResult = await repository.setThemeMode(AppThemeMode.dark);
      expect(darkResult.isSuccess(), isTrue);
      expect(
        (await repository.getThemeMode()).getOrNull(),
        equals(AppThemeMode.dark),
      );

      // Update to light mode
      final lightResult = await repository.setThemeMode(AppThemeMode.light);
      expect(lightResult.isSuccess(), isTrue);
      expect(
        (await repository.getThemeMode()).getOrNull(),
        equals(AppThemeMode.light),
      );

      // Update back to system mode
      final systemResult = await repository.setThemeMode(AppThemeMode.system);
      expect(systemResult.isSuccess(), isTrue);
      expect(
        (await repository.getThemeMode()).getOrNull(),
        equals(AppThemeMode.system),
      );
    });

    test(
      'unknown or corrupt stored theme value falls back to AppThemeMode.system',
      () async {
        SharedPreferences.setMockInitialValues({
          'theme_mode': 'invalid_mode_value',
        });
        final prefs = await SharedPreferences.getInstance();
        final repository = SharedPrefsThemePreferenceRepository(prefs);

        final result = await repository.getThemeMode();
        expect(result.isSuccess(), isTrue);
        expect(result.getOrNull(), equals(AppThemeMode.system));
      },
    );
  });
}
