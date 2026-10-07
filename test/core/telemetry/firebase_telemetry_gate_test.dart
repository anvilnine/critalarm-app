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

  group('FirebaseTelemetryGate', () {
    late MockFirebaseAnalytics analytics;
    late MockFirebaseCrashlytics crashlytics;
    late MockFirebaseRemoteConfig remoteConfig;
    late FirebaseTelemetryGate gate;

    setUp(() {
      analytics = MockFirebaseAnalytics();
      crashlytics = MockFirebaseCrashlytics();
      remoteConfig = MockFirebaseRemoteConfig();

      when(
        () => analytics.setAnalyticsCollectionEnabled(any()),
      ).thenAnswer((_) async {});
      when(() => analytics.resetAnalyticsData()).thenAnswer((_) async {});
      when(
        () => crashlytics.setCrashlyticsCollectionEnabled(any()),
      ).thenAnswer((_) async {});
      when(
        () => remoteConfig.setConfigSettings(any()),
      ).thenAnswer((_) async {});
      when(() => remoteConfig.setDefaults(any())).thenAnswer((_) async {});
      when(() => remoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
      when(() => remoteConfig.getBool(any())).thenReturn(false);

      gate = FirebaseTelemetryGate(
        analytics: analytics,
        crashlytics: crashlytics,
        remoteConfig: remoteConfig,
      );
    });

    test(
      'safe initialization handles uninitialized Firebase gracefully',
      () async {
        final unconfiguredGate = FirebaseTelemetryGate();
        expect(unconfiguredGate.initialize, returnsNormally);
        expect(unconfiguredGate.paywallEnabled, isFalse);
        expect(unconfiguredGate.isPaywallEnabled, isFalse);
        expect(unconfiguredGate.onboardingFlowJson, isEmpty);
        expect(
          () => unconfiguredGate.setAnalyticsEnabled(true),
          returnsNormally,
        );
        expect(
          () => unconfiguredGate.setCrashlyticsEnabled(true),
          returnsNormally,
        );
      },
    );

    test(
      'initialize disables collection at startup and configures defaults',
      () async {
        await gate.initialize();

        // Collection must be disabled at startup
        verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
        verify(
          () => crashlytics.setCrashlyticsCollectionEnabled(false),
        ).called(1);
        expect(gate.isAnalyticsEnabled, isFalse);
        expect(gate.isCrashlyticsEnabled, isFalse);

        // Remote Config 1-hour fetch interval configuration
        final capturedSettings =
            verify(
                  () => remoteConfig.setConfigSettings(captureAny()),
                ).captured.single
                as RemoteConfigSettings;

        expect(
          capturedSettings.minimumFetchInterval,
          equals(const Duration(hours: 1)),
        );
        expect(
          capturedSettings.fetchTimeout,
          equals(const Duration(seconds: 10)),
        );

        // Typed config defaults with paywall_enabled: false
        verify(
          () => remoteConfig.setDefaults(const {
            'paywall_enabled': false,
            'paywall_variant': 'straight',
            'onboarding_flow': '',
            'paywall_layout': '',
            'pro_paywall_layout': '',
          }),
        ).called(1);

        verify(() => remoteConfig.fetchAndActivate()).called(1);
        expect(gate.isInitialized, isTrue);
      },
    );

    test('initialize handles fetchAndActivate failure gracefully', () async {
      when(
        () => remoteConfig.fetchAndActivate(),
      ).thenThrow(Exception('Network error'));

      await expectLater(gate.initialize(), completes);
      expect(gate.isInitialized, isTrue);
    });

    test('setAnalyticsEnabled(true) enables analytics collection', () async {
      await gate.setAnalyticsEnabled(true);

      verify(() => analytics.setAnalyticsCollectionEnabled(true)).called(1);
      verifyNever(() => analytics.resetAnalyticsData());
      expect(gate.isAnalyticsEnabled, isTrue);
    });

    test('setAnalyticsEnabled(false) disables analytics and calls '
        'resetAnalyticsData', () async {
      await gate.setAnalyticsEnabled(false);

      verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
      verify(() => analytics.resetAnalyticsData()).called(1);
      expect(gate.isAnalyticsEnabled, isFalse);
    });

    test('setCrashlyticsEnabled(true) enables crash reporting', () async {
      await gate.setCrashlyticsEnabled(true);

      verify(() => crashlytics.setCrashlyticsCollectionEnabled(true)).called(1);
      expect(gate.isCrashlyticsEnabled, isTrue);
    });

    test('setCrashlyticsEnabled(false) disables crash reporting', () async {
      await gate.setCrashlyticsEnabled(false);

      verify(
        () => crashlytics.setCrashlyticsCollectionEnabled(false),
      ).called(1);
      expect(gate.isCrashlyticsEnabled, isFalse);
    });

    test('paywallEnabled returns typed bool from Remote Config', () {
      when(() => remoteConfig.getBool('paywall_enabled')).thenReturn(true);

      expect(gate.paywallEnabled, isTrue);
      expect(gate.isPaywallEnabled, isTrue);
      verify(() => remoteConfig.getBool('paywall_enabled')).called(2);
    });

    test('paywallEnabled returns false when remoteConfig throws', () {
      when(
        () => remoteConfig.getBool('paywall_enabled'),
      ).thenThrow(Exception('Config missing'));

      expect(gate.paywallEnabled, isFalse);
      expect(gate.isPaywallEnabled, isFalse);
    });
  });

  group('the paywall layout values', () {
    late MockFirebaseRemoteConfig remoteConfig;
    late FirebaseTelemetryGate gate;

    setUp(() {
      remoteConfig = MockFirebaseRemoteConfig();
      gate = FirebaseTelemetryGate(remoteConfig: remoteConfig);
    });

    test('both default to an empty string, the shipped paywall', () {
      const defaults = FirebaseTelemetryGate.remoteConfigDefaults;
      expect(defaults['paywall_layout'], isEmpty);
      expect(defaults['pro_paywall_layout'], isEmpty);
      expect(FirebaseTelemetryGate().paywallLayoutKey, isEmpty);
      expect(FirebaseTelemetryGate().proPaywallLayoutKey, isEmpty);
    });

    test('each reads its own key, already activated, with no fetch', () {
      when(() => remoteConfig.getString('paywall_layout')).thenReturn('auto');
      when(
        () => remoteConfig.getString('pro_paywall_layout'),
      ).thenReturn('sheet');

      expect(gate.paywallLayoutKey, 'auto');
      expect(gate.proPaywallLayoutKey, 'sheet');
      verifyNever(() => remoteConfig.fetchAndActivate());
    });

    test('a read that throws is empty', () {
      when(() => remoteConfig.getString(any())).thenThrow(Exception('gone'));

      expect(gate.paywallLayoutKey, isEmpty);
      expect(gate.proPaywallLayoutKey, isEmpty);
    });
  });

  group('onboardingFlowJson', () {
    late MockFirebaseRemoteConfig remoteConfig;
    late FirebaseTelemetryGate gate;

    setUp(() {
      remoteConfig = MockFirebaseRemoteConfig();
      gate = FirebaseTelemetryGate(remoteConfig: remoteConfig);
    });

    test('the key defaults to an empty string', () {
      expect(
        FirebaseTelemetryGate.remoteConfigDefaults['onboarding_flow'],
        isEmpty,
      );
    });

    test('returns the raw string Remote Config holds', () {
      when(
        () => remoteConfig.getString('onboarding_flow'),
      ).thenReturn('{"id": "x", "steps": ["welcome"]}');

      expect(gate.onboardingFlowJson, '{"id": "x", "steps": ["welcome"]}');
    });

    test('returns an empty string when Remote Config throws', () {
      when(
        () => remoteConfig.getString('onboarding_flow'),
      ).thenThrow(Exception('Config missing'));

      expect(gate.onboardingFlowJson, isEmpty);
    });

    test('returns an empty string when there is no Remote Config', () {
      expect(FirebaseTelemetryGate().onboardingFlowJson, isEmpty);
    });
  });

  group('NoopTelemetryGate', () {
    test(
      'provides safe no-op implementation with default or custom flag',
      () async {
        const defaultGate = NoopTelemetryGate();
        expect(defaultGate.paywallEnabled, isFalse);
        expect(defaultGate.isPaywallEnabled, isFalse);
        expect(defaultGate.onboardingFlowJson, isEmpty);
        await defaultGate.initialize();
        await defaultGate.setAnalyticsEnabled(true);
        await defaultGate.setCrashlyticsEnabled(true);

        const activeGate = NoopTelemetryGate(paywallEnabled: true);
        expect(activeGate.paywallEnabled, isTrue);
        expect(activeGate.isPaywallEnabled, isTrue);
      },
    );
  });
}
