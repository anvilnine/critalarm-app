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

        // Typed config defaults: the two setup keys and no paywall key.
        verify(
          () => remoteConfig.setDefaults(const {
            'onboarding_flow': '',
            'onboarding_offer': '',
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

    group('recordError', () {
      setUp(() {
        when(
          () => crashlytics.recordError(
            any<dynamic>(),
            any(),
            reason: any<dynamic>(named: 'reason'),
            fatal: any(named: 'fatal'),
          ),
        ).thenAnswer((_) async {});
      });

      test('records nothing while crash reporting is off', () async {
        await gate.recordError(StateError('x'), StackTrace.current);
        await gate.setCrashlyticsEnabled(true);
        await gate.setCrashlyticsEnabled(false);
        await gate.recordError(StateError('x'), StackTrace.current);

        verifyNever(
          () => crashlytics.recordError(
            any<dynamic>(),
            any(),
            reason: any<dynamic>(named: 'reason'),
            fatal: any(named: 'fatal'),
          ),
        );
      });

      test('sends the type and the stack, never the message', () async {
        await gate.setCrashlyticsEnabled(true);
        final stack = StackTrace.current;

        await gate.recordError(
          const FormatException('the words of a message'),
          stack,
          fatal: true,
          reason: 'widgets library',
        );

        final sent = verify(
          () => crashlytics.recordError(
            captureAny<dynamic>(),
            stack,
            reason: 'widgets library',
            fatal: true,
          ),
        ).captured.single;
        expect(sent, isA<ReportedError>());
        expect(sent.toString(), 'FormatException');
        expect(sent.toString(), isNot(contains('words')));
      });

      test('a plugin that throws does not throw out of the gate', () async {
        await gate.setCrashlyticsEnabled(true);
        when(
          () => crashlytics.recordError(
            any<dynamic>(),
            any(),
            reason: any<dynamic>(named: 'reason'),
            fatal: any(named: 'fatal'),
          ),
        ).thenThrow(Exception('no channel'));

        await expectLater(
          gate.recordError(StateError('x'), StackTrace.current),
          completes,
        );
      });

      test('a gate with no Firebase app drops the report', () async {
        final bare = FirebaseTelemetryGate();
        await bare.setCrashlyticsEnabled(true);
        await expectLater(
          bare.recordError(StateError('x'), StackTrace.current),
          completes,
        );
      });
    });
  });

  group('a run that may not send', () {
    late MockFirebaseAnalytics analytics;
    late MockFirebaseCrashlytics crashlytics;
    late MockFirebaseRemoteConfig remoteConfig;

    setUp(() {
      analytics = MockFirebaseAnalytics();
      crashlytics = MockFirebaseCrashlytics();
      remoteConfig = MockFirebaseRemoteConfig();
      when(
        () => analytics.setAnalyticsCollectionEnabled(any()),
      ).thenAnswer((_) async {});
      when(() => analytics.resetAnalyticsData()).thenAnswer((_) async {});
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => crashlytics.setCrashlyticsCollectionEnabled(any()),
      ).thenAnswer((_) async {});
      when(
        () => crashlytics.recordError(
          any<dynamic>(),
          any(),
          reason: any<dynamic>(named: 'reason'),
          fatal: any(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => remoteConfig.setConfigSettings(any()),
      ).thenAnswer((_) async {});
      when(() => remoteConfig.setDefaults(any())).thenAnswer((_) async {});
      when(() => remoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
    });

    FirebaseTelemetryGate gateOn({required bool isWeb}) =>
        FirebaseTelemetryGate(
          analytics: analytics,
          crashlytics: crashlytics,
          remoteConfig: remoteConfig,
          collectionAllowed: false,
          isWeb: isWeb,
        );

    test('on a phone it saves both switches off, then never turns them '
        'on', () async {
      final gate = gateOn(isWeb: false);
      await gate.initialize();
      await gate.setAnalyticsEnabled(true);
      await gate.setCrashlyticsEnabled(true);
      await gate.logEvent('onboarding_step_viewed', {'step': 'welcome'});
      await gate.recordError(StateError('x'), StackTrace.current);

      verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
      verifyNever(() => analytics.setAnalyticsCollectionEnabled(true));
      verify(
        () => crashlytics.setCrashlyticsCollectionEnabled(false),
      ).called(1);
      verifyNever(() => crashlytics.setCrashlyticsCollectionEnabled(true));
      verifyNever(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      );
      verifyNever(
        () => crashlytics.recordError(
          any<dynamic>(),
          any(),
          reason: any<dynamic>(named: 'reason'),
          fatal: any(named: 'fatal'),
        ),
      );
      expect(gate.isAnalyticsEnabled, isFalse);
      expect(gate.isCrashlyticsEnabled, isFalse);
    });

    test('on web it never touches analytics or crash reporting', () async {
      final gate = gateOn(isWeb: true);
      await gate.initialize();
      await gate.setAnalyticsEnabled(true);
      await gate.setAnalyticsEnabled(false);
      await gate.setCrashlyticsEnabled(true);
      await gate.logEvent('onboarding_step_viewed');
      await gate.recordError(StateError('x'), StackTrace.current);

      verifyZeroInteractions(analytics);
      verifyZeroInteractions(crashlytics);
      expect(gate.isAnalyticsEnabled, isFalse);
    });

    test('Remote Config still loads', () async {
      final gate = gateOn(isWeb: true);
      await gate.initialize();

      verify(() => remoteConfig.fetchAndActivate()).called(1);
      expect(gate.isInitialized, isTrue);
    });

    test('the user switch is ignored even before initialize', () async {
      final gate = gateOn(isWeb: false);
      await gate.setAnalyticsEnabled(true);
      await gate.logEvent('x');

      verifyNever(() => analytics.setAnalyticsCollectionEnabled(true));
      verifyNever(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      );
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

  group('onboardingOfferJson', () {
    late MockFirebaseRemoteConfig remoteConfig;
    late FirebaseTelemetryGate gate;

    setUp(() {
      remoteConfig = MockFirebaseRemoteConfig();
      gate = FirebaseTelemetryGate(remoteConfig: remoteConfig);
    });

    test('the key defaults to an empty string', () {
      expect(
        FirebaseTelemetryGate.remoteConfigDefaults['onboarding_offer'],
        isEmpty,
      );
    });

    test('returns the raw string Remote Config holds', () {
      when(
        () => remoteConfig.getString('onboarding_offer'),
      ).thenReturn('{"enabled": true}');

      expect(gate.onboardingOfferJson, '{"enabled": true}');
    });

    test('returns an empty string when Remote Config throws or is absent', () {
      when(
        () => remoteConfig.getString('onboarding_offer'),
      ).thenThrow(Exception('Config missing'));

      expect(gate.onboardingOfferJson, isEmpty);
      expect(FirebaseTelemetryGate().onboardingOfferJson, isEmpty);
      expect(const NoopTelemetryGate().onboardingOfferJson, isEmpty);
    });
  });

  group('NoopTelemetryGate', () {
    test(
      'provides safe no-op implementation',
      () async {
        const defaultGate = NoopTelemetryGate();
        expect(defaultGate.onboardingFlowJson, isEmpty);
        await defaultGate.initialize();
        await defaultGate.setAnalyticsEnabled(true);
        await defaultGate.setCrashlyticsEnabled(true);
      },
    );
  });
}
