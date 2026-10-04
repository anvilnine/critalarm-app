import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_funnel_hook.dart';
import 'package:critalarm/features/onboarding/domain/setup_stats_consent.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:critalarm/features/settings/data/repositories/observed_privacy_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_privacy_repository.dart';
import 'package:critalarm/features/settings/domain/entities/privacy_settings.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/settings/domain/usecases/set_analytics_enabled_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/onboarding_flow_fakes.dart';

/// Drops events unless collection is on, like the Firebase gate, and writes
/// down every call.
class _Gate extends NoopTelemetryGate {
  final calls = <String>[];
  final sent = <(String, Map<String, Object?>)>[];
  bool enabled = false;

  @override
  Future<void> setAnalyticsEnabled(bool enabled) async {
    calls.add('setAnalyticsEnabled');
    this.enabled = enabled;
  }

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async {
    calls.add('logEvent');
    if (enabled) sent.add((name, Map<String, Object?>.of(parameters ?? {})));
  }
}

void main() {
  late SharedPreferences prefs;
  late _Gate gate;
  late OnboardingFunnel funnel;
  late ObservedPrivacyRepository privacy;
  late EngineHarness harness;

  EngineHarness newHarness({FakeOnboardingFlowRepository? repository}) =>
      EngineHarness(
        repository: repository,
        onStepEvent: (event) => reportStepToFunnel(funnel, event),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gate = _Gate();
    funnel = OnboardingFunnel(
      prefs: prefs,
      gate: gate,
      stepIds: OnboardingStepRegistry.requiresById.keys.toSet(),
    );
    privacy = ObservedPrivacyRepository(
      SharedPrefsPrivacyRepository(prefs),
      onAnalyticsChoice: ({required isOn}) => funnel.answered(isOn: isOn),
    );
    harness = newHarness();
  });

  /// A whole run through the default flow, up to the last step opening.
  Future<void> runToHookUp() async {
    await harness.engine.resume();
    for (final step in BundledOnboardingFlows.defaultFlow.steps) {
      if (step == OnboardingStepId.hookUp) break;
      await harness.engine.finishStep(step);
    }
  }

  bool hasBuffer() => prefs.containsKey(OnboardingFunnel.bufferKey);

  group('what the engine reports', () {
    test('every step opens and finishes once, the last one included', () async {
      await runToHookUp();
      await harness.engine.finishStep(OnboardingStepId.hookUp);

      final steps = BundledOnboardingFlows.defaultFlow.steps;
      final entered = harness.events
          .where((e) => e.kind == OnboardingStepEventKind.entered)
          .map((e) => e.stepId);
      final finished = harness.events
          .where((e) => e.kind == OnboardingStepEventKind.finished)
          .map((e) => e.stepId);
      expect(entered, steps);
      expect(finished, steps);
      expect(harness.events.map((e) => e.flowId).toSet(), {
        BundledOnboardingFlows.defaultFlow.id,
      });
    });

    test('asking where the user stands again reports nothing new', () async {
      await harness.engine.resume();
      final once = harness.events.length;

      // Reading the flow, the pinned list or whether a step is done opens
      // nothing.
      harness.engine
        ..chooseFlow()
        ..runningFlow();
      await harness.engine.isStepSatisfied(OnboardingStepId.connect);

      expect(harness.events, hasLength(once));
    });
  });

  group('who is counted', () {
    test('a replay records nothing', () async {
      await harness.engine.finishStep(OnboardingStepId.welcome, isReplay: true);
      await harness.engine.finishStep(
        OnboardingStepId.howItRings,
        isReplay: true,
      );
      expect(harness.events, isNotEmpty);
      expect(harness.events.every((e) => e.isReplay), isTrue);

      expect(hasBuffer(), isFalse);
      expect(gate.calls, isEmpty);
    });

    test(
      'a finished user records nothing when a setup screen opens',
      () async {
        await runToHookUp();
        await harness.engine.finishStep(OnboardingStepId.hookUp);
        await funnel.answered(isOn: true);
        gate.sent.clear();
        final eventsBefore = harness.events.length;

        final destination = await harness.engine.finishStep(
          OnboardingStepId.connect,
        );

        expect(destination.isBack, isTrue);
        expect(harness.events, hasLength(eventsBefore));
        expect(gate.sent, isEmpty);
      },
    );
  });

  group('the answer', () {
    test(
      'Done with the switch off leaves it unanswered, the Home ask answers it',
      () async {
        await runToHookUp();
        // The switch was never touched, so nothing was written.
        await harness.engine.finishStep(OnboardingStepId.hookUp);

        expect(funnel.state, OnboardingFunnelState.unanswered);
        expect(hasBuffer(), isTrue);
        expect(gate.calls, isEmpty);

        // Home consent sheet, Share with analytics on: it saves the choice
        // through the same repository the sheet uses.
        await privacy.setAnalyticsEnabled(enabled: true);

        final steps = BundledOnboardingFlows.defaultFlow.steps;
        expect(gate.sent, hasLength(steps.length * 2));
        expect(hasBuffer(), isFalse);
        expect(gate.sent.last.$1, AnalyticsEvents.onboardingStepCompleted);
        expect(gate.sent.last.$2['step'], OnboardingStepId.hookUp);
      },
    );

    test('Not now on the Home ask deletes what was waiting', () async {
      await runToHookUp();
      await harness.engine.finishStep(OnboardingStepId.hookUp);

      await funnel.answered(isOn: false);

      expect(hasBuffer(), isFalse);
      expect(gate.calls, isEmpty);
    });

    test(
      'the setup switch on sends the waiting events past a gate still off',
      () async {
        await runToHookUp();
        final consent = SetupStatsConsent(privacy: privacy, telemetry: gate);
        expect(gate.enabled, isFalse);

        expect(await consent.answer(isOn: true), isTrue);

        expect(gate.sent, hasLength(greaterThan(1)));
        expect(hasBuffer(), isFalse);

        // Done, after the switch: sent live.
        gate.sent.clear();
        await harness.engine.finishStep(OnboardingStepId.hookUp);
        expect(gate.sent.single.$2['step'], OnboardingStepId.hookUp);
      },
    );

    test('the setup switch on and then off ends as opted out', () async {
      await runToHookUp();
      final consent = SetupStatsConsent(privacy: privacy, telemetry: gate);
      await consent.answer(isOn: true);
      gate.sent.clear();

      await consent.answer(isOn: false);
      await harness.engine.finishStep(OnboardingStepId.hookUp);

      expect(funnel.state, OnboardingFunnelState.optedOut);
      expect(gate.sent, isEmpty);
      expect(hasBuffer(), isFalse);
    });

    test('Settings > Privacy answers it, either way', () async {
      final setAnalytics = SetAnalyticsEnabledUsecase(privacy);

      await runToHookUp();
      await setAnalytics(true);
      expect(gate.sent, isNotEmpty);
      expect(hasBuffer(), isFalse);

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      gate = _Gate();
      funnel = OnboardingFunnel(
        prefs: prefs,
        gate: gate,
        stepIds: OnboardingStepRegistry.requiresById.keys.toSet(),
      );
      privacy = ObservedPrivacyRepository(
        SharedPrefsPrivacyRepository(prefs),
        onAnalyticsChoice: ({required isOn}) => funnel.answered(isOn: isOn),
      );
      harness = newHarness();
      await runToHookUp();
      expect(hasBuffer(), isTrue);

      await SetAnalyticsEnabledUsecase(privacy)(false);
      expect(hasBuffer(), isFalse);
      expect(gate.calls, isEmpty);
    });

    test('a choice that could not be saved is not an answer', () async {
      final failing = ObservedPrivacyRepository(
        _FailingPrivacy(),
        onAnalyticsChoice: ({required isOn}) => funnel.answered(isOn: isOn),
      );
      await runToHookUp();

      await failing.setAnalyticsEnabled(enabled: true);

      expect(funnel.state, OnboardingFunnelState.unanswered);
      expect(hasBuffer(), isTrue);
      expect(gate.calls, isEmpty);
    });
  });

  group('what may become a parameter', () {
    test('every id the registry holds is accepted', () async {
      await funnel.answered(isOn: true);
      for (final id in OnboardingStepRegistry.requiresById.keys) {
        await funnel.stepViewed(id, BundledOnboardingFlows.defaultFlow.id);
      }
      expect(gate.sent, hasLength(OnboardingStepRegistry.requiresById.length));
    });

    test('every bundled flow id is accepted', () async {
      await funnel.answered(isOn: true);
      for (final flow in BundledOnboardingFlows.all) {
        await funnel.stepViewed(OnboardingStepId.welcome, flow.id);
      }
      expect(gate.sent, hasLength(BundledOnboardingFlows.all.length));
    });
  });
}

class _FailingPrivacy implements PrivacyRepository {
  @override
  Future<AppResult<PrivacySettings>> getPrivacySettings() async =>
      const PrivacySettings().toSuccess();

  @override
  Future<AppResult<Unit>> setAnalyticsEnabled({required bool enabled}) async =>
      const Failure.unexpected(message: 'no').toFailure();

  @override
  Future<AppResult<Unit>> setCrashReportingEnabled({
    required bool enabled,
  }) async => unit.toSuccess();
}
