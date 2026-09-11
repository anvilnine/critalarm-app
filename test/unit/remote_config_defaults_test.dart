import 'package:critalarm/core/telemetry/firebase_telemetry_gate.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

class MockFirebaseRemoteConfig extends Mock implements FirebaseRemoteConfig {}

class FakeRemoteConfigSettings extends Fake implements RemoteConfigSettings {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRemoteConfigSettings());
  });

  group('Remote Config Settings and Defaults', () {
    late MockFirebaseAnalytics mockAnalytics;
    late MockFirebaseCrashlytics mockCrashlytics;
    late MockFirebaseRemoteConfig mockRemoteConfig;
    late FirebaseTelemetryGate gate;

    setUp(() {
      mockAnalytics = MockFirebaseAnalytics();
      mockCrashlytics = MockFirebaseCrashlytics();
      mockRemoteConfig = MockFirebaseRemoteConfig();

      when(
        () => mockAnalytics.setAnalyticsCollectionEnabled(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockCrashlytics.setCrashlyticsCollectionEnabled(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockRemoteConfig.setConfigSettings(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockRemoteConfig.setDefaults(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockRemoteConfig.fetchAndActivate(),
      ).thenAnswer((_) async => true);
      when(
        () => mockRemoteConfig.getBool(any()),
      ).thenReturn(false);

      gate = FirebaseTelemetryGate(
        analytics: mockAnalytics,
        crashlytics: mockCrashlytics,
        remoteConfig: mockRemoteConfig,
      );
    });

    test(
      'static constants define 1-hour fetch interval and typed defaults map',
      () {
        // 1-hour fetch interval
        expect(
          FirebaseTelemetryGate.minimumFetchInterval,
          equals(const Duration(hours: 1)),
        );

        // 10-second default fetch timeout
        expect(
          FirebaseTelemetryGate.defaultFetchTimeout,
          equals(const Duration(seconds: 10)),
        );

        // Typed defaults map: {'paywall_enabled': false}
        expect(
          FirebaseTelemetryGate.remoteConfigDefaults,
          equals(const {'paywall_enabled': false}),
        );
        expect(
          FirebaseTelemetryGate.remoteConfigDefaults['paywall_enabled'],
          isFalse,
        );
      },
    );

    test(
      'initialize applies 1-hour fetch interval and sets typed defaults map',
      () async {
        await gate.initialize();

        // Verify setConfigSettings was called with
        // minimumFetchInterval = 1 hour
        final capturedSettings =
            verify(
                  () => mockRemoteConfig.setConfigSettings(captureAny()),
                ).captured.single
                as RemoteConfigSettings;

        expect(
          capturedSettings.minimumFetchInterval,
          equals(const Duration(hours: 1)),
          reason: 'Remote Config fetch interval must be configured to 1 hour',
        );
        expect(
          capturedSettings.fetchTimeout,
          equals(const Duration(seconds: 10)),
        );

        // Verify setDefaults was called with typed defaults map
        verify(
          () => mockRemoteConfig.setDefaults(const {
            'paywall_enabled': false,
          }),
        ).called(1);

        // Verify fetchAndActivate was called to fetch latest remote config
        verify(() => mockRemoteConfig.fetchAndActivate()).called(1);
      },
    );

    test('initialize handles fetchAndActivate exception gracefully', () async {
      when(
        () => mockRemoteConfig.fetchAndActivate(),
      ).thenThrow(Exception('Remote config fetch timeout'));

      await expectLater(gate.initialize(), completes);
      expect(gate.isInitialized, isTrue);
    });

    test('typed getter paywallEnabled returns false by default', () {
      when(
        () => mockRemoteConfig.getBool('paywall_enabled'),
      ).thenReturn(false);

      expect(gate.paywallEnabled, isFalse);
      expect(gate.isPaywallEnabled, isFalse);
      verify(() => mockRemoteConfig.getBool('paywall_enabled')).called(2);
    });

    test(
      'typed getter paywallEnabled returns true when remote config is true',
      () {
        when(
          () => mockRemoteConfig.getBool('paywall_enabled'),
        ).thenReturn(true);

        expect(
          gate.paywallEnabled,
          isTrue,
          reason:
              'paywallEnabled must return true when remote config flag is true',
        );
        expect(gate.isPaywallEnabled, isTrue);
        verify(() => mockRemoteConfig.getBool('paywall_enabled')).called(2);
      },
    );

    test(
      'typed getter paywallEnabled returns false on remoteConfig exception',
      () {
        when(
          () => mockRemoteConfig.getBool('paywall_enabled'),
        ).thenThrow(Exception('Missing key'));

        expect(gate.paywallEnabled, isFalse);
        expect(gate.isPaywallEnabled, isFalse);
      },
    );

    test(
      'typed getter paywallEnabled returns false when gate is unconfigured',
      () {
        final unconfigured = FirebaseTelemetryGate();
        expect(unconfigured.paywallEnabled, isFalse);
        expect(unconfigured.isPaywallEnabled, isFalse);
      },
    );

    test('NoopTelemetryGate supports default false and custom true', () {
      const defaultNoop = NoopTelemetryGate();
      expect(defaultNoop.paywallEnabled, isFalse);
      expect(defaultNoop.isPaywallEnabled, isFalse);

      const activeNoop = NoopTelemetryGate(paywallEnabled: true);
      expect(activeNoop.paywallEnabled, isTrue);
      expect(activeNoop.isPaywallEnabled, isTrue);
    });
  });
}
