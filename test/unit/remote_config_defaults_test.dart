import 'dart:io';

import 'package:critalarm/core/telemetry/firebase_telemetry_gate.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

class MockFirebaseRemoteConfig extends Mock implements FirebaseRemoteConfig {}

class FakeRemoteConfigSettings extends Fake implements RemoteConfigSettings {}

/// The ten paywall keys Remote Config held before the paywalls were coded.
const _removedPaywallKeys = [
  'paywall_layout',
  'pro_paywall_layout',
  'paywall_intro',
  'pro_paywall_intro',
  'paywall_thanks',
  'pro_paywall_thanks',
  'paywall_outro',
  'pro_paywall_outro',
  'paywall_variant',
  'paywall_enabled',
];

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

        // Typed defaults map: onboarding_flow and onboarding_offer empty,
        // and nothing else. No paywall value is remote.
        expect(
          FirebaseTelemetryGate.remoteConfigDefaults,
          equals(
            const {
              'onboarding_flow': '',
              'onboarding_offer': '',
            },
          ),
        );
        for (final key in _removedPaywallKeys) {
          expect(
            FirebaseTelemetryGate.remoteConfigDefaults.containsKey(key),
            isFalse,
            reason: key,
          );
        }
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
            'onboarding_flow': '',
            'onboarding_offer': '',
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

    test('no paywall value is read from Remote Config', () {
      // The gate has no paywall getter left, so a paywall cannot follow a
      // remote value. Neither file may name one of the removed keys, or the
      // word paywall at all.
      for (final path in [
        'lib/core/telemetry/telemetry_gate.dart',
        'lib/core/telemetry/firebase_telemetry_gate.dart',
      ]) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(source.contains('paywall'), isFalse, reason: path);
        for (final key in _removedPaywallKeys) {
          expect(source.contains(key), isFalse, reason: '$path names $key');
        }
      }
    });

    test('the two setup keys are still read', () {
      when(
        () => mockRemoteConfig.getString('onboarding_flow'),
      ).thenReturn('flow');
      when(
        () => mockRemoteConfig.getString('onboarding_offer'),
      ).thenReturn('offer');
      expect(gate.onboardingFlowJson, 'flow');
      expect(gate.onboardingOfferJson, 'offer');
      expect(FirebaseTelemetryGate.onboardingFlowKey, 'onboarding_flow');
      expect(FirebaseTelemetryGate.onboardingOfferKey, 'onboarding_offer');
    });
  });
}
