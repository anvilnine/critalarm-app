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

  group('FirebaseTelemetryGate Startup Logic', () {
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
        () => mockAnalytics.resetAnalyticsData(),
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
      'proves startup collection is strictly disabled for analytics and '
      'crashlytics',
      () async {
        await gate.initialize();

        // Proves startup collection is disabled:
        // setAnalyticsCollectionEnabled(false)
        verify(
          () => mockAnalytics.setAnalyticsCollectionEnabled(false),
        ).called(1);

        // Proves startup collection is disabled:
        // setCrashlyticsCollectionEnabled(false)
        verify(
          () => mockCrashlytics.setCrashlyticsCollectionEnabled(false),
        ).called(1);

        expect(gate.isAnalyticsEnabled, isFalse);
        expect(gate.isCrashlyticsEnabled, isFalse);
        expect(gate.isInitialized, isTrue);
      },
    );

    test('proves toggle ON enables analytics collection', () async {
      await gate.setAnalyticsEnabled(true);

      verify(
        () => mockAnalytics.setAnalyticsCollectionEnabled(true),
      ).called(1);
      verifyNever(() => mockAnalytics.resetAnalyticsData());
      expect(gate.isAnalyticsEnabled, isTrue);
    });

    test(
      'proves toggle OFF disables collection AND calls resetAnalyticsData()',
      () async {
        // First turn ON
        await gate.setAnalyticsEnabled(true);
        expect(gate.isAnalyticsEnabled, isTrue);

        // Toggle OFF: must disable collection AND reset analytics data
        await gate.setAnalyticsEnabled(false);

        verify(
          () => mockAnalytics.setAnalyticsCollectionEnabled(false),
        ).called(1);
        verify(
          () => mockAnalytics.resetAnalyticsData(),
        ).called(1);
        expect(gate.isAnalyticsEnabled, isFalse);
      },
    );

    test('proves crashlytics toggle ON enables collection', () async {
      await gate.setCrashlyticsEnabled(true);

      verify(
        () => mockCrashlytics.setCrashlyticsCollectionEnabled(true),
      ).called(1);
      expect(gate.isCrashlyticsEnabled, isTrue);
    });

    test('proves crashlytics toggle OFF disables collection', () async {
      // First turn ON
      await gate.setCrashlyticsEnabled(true);
      expect(gate.isCrashlyticsEnabled, isTrue);

      // Toggle OFF
      await gate.setCrashlyticsEnabled(false);

      verify(
        () => mockCrashlytics.setCrashlyticsCollectionEnabled(false),
      ).called(1);
      expect(gate.isCrashlyticsEnabled, isFalse);
    });

    test(
      'proves error handling when analytics platform methods throw',
      () async {
        when(
          () => mockAnalytics.setAnalyticsCollectionEnabled(any()),
        ).thenThrow(Exception('Platform channel error'));
        when(
          () => mockAnalytics.resetAnalyticsData(),
        ).thenThrow(Exception('Platform channel error'));

        // Should complete without uncaught exceptions
        await expectLater(gate.setAnalyticsEnabled(true), completes);
        await expectLater(gate.setAnalyticsEnabled(false), completes);
      },
    );

    test(
      'proves error handling when crashlytics platform methods throw',
      () async {
        when(
          () => mockCrashlytics.setCrashlyticsCollectionEnabled(any()),
        ).thenThrow(Exception('Crashlytics error'));

        await expectLater(gate.setCrashlyticsEnabled(true), completes);
        await expectLater(gate.setCrashlyticsEnabled(false), completes);
      },
    );
  });

  group('FirebaseTelemetryGate Uninitialized Fallback', () {
    test(
      'proves graceful fallback when Firebase is completely uninitialized',
      () async {
        final unconfiguredGate = FirebaseTelemetryGate();

        expect(unconfiguredGate.isInitialized, isFalse);
        expect(unconfiguredGate.isAnalyticsEnabled, isFalse);
        expect(unconfiguredGate.isCrashlyticsEnabled, isFalse);
        expect(unconfiguredGate.paywallEnabled, isFalse);
        expect(unconfiguredGate.isPaywallEnabled, isFalse);

        // initialize should not throw when Firebase is missing
        await expectLater(unconfiguredGate.initialize(), completes);

        // toggle calls should not crash
        await expectLater(
          unconfiguredGate.setAnalyticsEnabled(true),
          completes,
        );
        await expectLater(
          unconfiguredGate.setAnalyticsEnabled(false),
          completes,
        );
        await expectLater(
          unconfiguredGate.setCrashlyticsEnabled(true),
          completes,
        );
        await expectLater(
          unconfiguredGate.setCrashlyticsEnabled(false),
          completes,
        );
      },
    );
  });

  group('TelemetryGate Interface Contract', () {
    test(
      'NoopTelemetryGate satisfies contract and defaults to false',
      () async {
        const gate = NoopTelemetryGate();
        expect(gate.paywallEnabled, isFalse);
        expect(gate.isPaywallEnabled, isFalse);

        await expectLater(gate.initialize(), completes);
        await expectLater(gate.setAnalyticsEnabled(true), completes);
        await expectLater(gate.setAnalyticsEnabled(false), completes);
        await expectLater(gate.setCrashlyticsEnabled(true), completes);
        await expectLater(gate.setCrashlyticsEnabled(false), completes);

        const activeGate = NoopTelemetryGate(paywallEnabled: true);
        expect(activeGate.paywallEnabled, isTrue);
        expect(activeGate.isPaywallEnabled, isTrue);
      },
    );
  });
}
