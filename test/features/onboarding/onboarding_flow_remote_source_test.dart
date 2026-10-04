import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/flow/remote_onboarding_flow_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

/// A gate whose Remote Config value can change, or throw, while a test runs.
class FakeFlowGate extends NoopTelemetryGate {
  FakeFlowGate([this.json = '']);

  String json;
  bool throws = false;

  @override
  String get onboardingFlowJson {
    if (throws) throw StateError('Remote Config is broken');
    return json;
  }
}

const _valid =
    '{"id": "2026-10-b", "steps": ["welcome", "how_it_rings", "connect", '
    '"permissions", "first_topic", "real_ring", "hook_up"]}';

void main() {
  late FakeFlowGate gate;
  late FakeOnboardingFlowSource developer;
  late EngineHarness harness;

  setUp(() {
    gate = FakeFlowGate();
    developer = FakeOnboardingFlowSource();
    harness = EngineHarness(
      sources: [
        developer,
        RemoteOnboardingFlowSource(gate),
        const BundledOnboardingFlowSource(),
      ],
    );
  });

  OnboardingFlow chosen() => harness.engine.chooseFlow();

  group('the source', () {
    test('a valid remote flow is used when there is no override', () {
      gate.json = _valid;

      expect(chosen().id, '2026-10-b');
      expect(chosen().steps, contains('hook_up'));
      expect(
        harness.engine.chooseFlowWithOrigin().origin,
        OnboardingFlowOrigin.remote,
      );
    });

    test('a developer override beats the remote flow', () {
      gate.json = _valid;
      developer.flow = BundledOnboardingFlows.legacy;

      expect(chosen(), BundledOnboardingFlows.legacy);
      expect(
        harness.engine.chooseFlowWithOrigin().origin,
        OnboardingFlowOrigin.developer,
      );
    });

    test('an empty string uses the bundled default', () {
      gate.json = '';

      expect(chosen(), BundledOnboardingFlows.defaultFlow);
      expect(
        harness.engine.chooseFlowWithOrigin().origin,
        OnboardingFlowOrigin.bundled,
      );
    });

    test('a blank string uses the bundled default', () {
      gate.json = '   ';
      expect(chosen(), BundledOnboardingFlows.defaultFlow);
    });

    for (final bad in {
      'malformed JSON': '{"id": "x", "steps": [',
      'not an object': '["welcome"]',
      'a plain word': 'legacy-1',
      'a missing id': '{"steps": ["welcome", "connect"]}',
      'an empty id': '{"id": "", "steps": ["welcome", "connect"]}',
      'a number id': '{"id": 7, "steps": ["welcome", "connect"]}',
      'an id with a space': '{"id": "a b", "steps": ["welcome", "connect"]}',
      'an id with a slash': '{"id": "a/b", "steps": ["welcome", "connect"]}',
      'an id with unicode': '{"id": "été", "steps": ["welcome", "connect"]}',
      'an id of 41 characters':
          '{"id": "${'a' * 41}", "steps": ["welcome", "connect"]}',
      'a missing steps': '{"id": "x"}',
      'steps that is not a list': '{"id": "x", "steps": "welcome"}',
      'steps holding a non-string':
          '{"id": "x", "steps": ["welcome", 3, "connect"]}',
    }.entries) {
      test('${bad.key} uses the bundled default', () {
        gate.json = bad.value;

        expect(RemoteOnboardingFlowSource(gate).current(), isNull);
        expect(chosen(), BundledOnboardingFlows.defaultFlow);
      });
    }

    test(
      'an id of 40 characters, dots, dashes and underscores is accepted',
      () {
        final id = 'A.b_c-9${'z' * 33}';
        expect(id.length, 40);
        gate.json = '{"id": "$id", "steps": ["welcome", "how_it_rings"]}';

        expect(chosen().id, id);
      },
    );

    test('an unknown step id is dropped and the rest is used', () {
      gate.json =
          '{"id": "x", "steps": ["welcome", "teleport", "how_it_rings", '
          '"connect"]}';

      expect(chosen().steps, ['welcome', 'how_it_rings', 'connect']);
      expect(
        harness.engine.chooseFlowWithOrigin().origin,
        OnboardingFlowOrigin.remote,
      );
    });

    test('welcome not first rejects the whole flow', () {
      gate.json = '{"id": "x", "steps": ["how_it_rings", "welcome"]}';

      expect(chosen(), BundledOnboardingFlows.defaultFlow);
      expect(
        harness.engine.chooseFlowWithOrigin().origin,
        OnboardingFlowOrigin.bundled,
      );
    });

    test('a step before one it requires rejects the whole flow', () {
      gate.json =
          '{"id": "x", "steps": ["welcome", "connect", "real_ring", '
          '"first_topic"]}';

      expect(chosen(), BundledOnboardingFlows.defaultFlow);
    });

    test('a flow that validates to nothing uses the bundled default', () {
      gate.json = '{"id": "x", "steps": ["nope", "nothing"]}';
      expect(chosen(), BundledOnboardingFlows.defaultFlow);

      gate.json = '{"id": "x", "steps": []}';
      expect(chosen(), BundledOnboardingFlows.defaultFlow);
    });

    test('a getter that throws uses the bundled default', () {
      gate.throws = true;

      expect(RemoteOnboardingFlowSource(gate).current, returnsNormally);
      expect(chosen(), BundledOnboardingFlows.defaultFlow);
    });

    test('only id and steps are read', () {
      gate.json =
          '{"id": "x", "steps": ["welcome", "connect"], '
          '"criticalDefault": true, "copy": {"welcome": "Hi"}}';

      expect(
        RemoteOnboardingFlowSource(gate).current(),
        const OnboardingFlow(id: 'x', steps: ['welcome', 'connect']),
      );
    });

    test('answers at once with what the gate holds, never a future', () {
      final OnboardingFlow? flow = RemoteOnboardingFlowSource(gate).current();
      expect(flow, isNull);
    });
  });

  group('pinning', () {
    test('a remote value that arrives after pinning changes nothing', () async {
      await harness.engine.finishStep('welcome');
      expect(harness.repository.pinned, BundledOnboardingFlows.defaultFlow);

      gate.json = '{"id": "late", "steps": ["welcome", "connect"]}';
      final next = await harness.engine.finishStep('how_it_rings');

      expect(harness.repository.pinned, BundledOnboardingFlows.defaultFlow);
      expect(harness.engine.runningFlow(), BundledOnboardingFlows.defaultFlow);
      expect(next.stepId, 'connect');
      // The next fresh install would get it.
      expect(harness.engine.chooseFlow().id, 'late');
    });

    test(
      'a remote value that changes after pinning keeps the old pin',
      () async {
        gate.json = _valid;
        await harness.engine.finishStep('welcome');
        expect(harness.repository.pinned?.id, '2026-10-b');

        gate.json = '{"id": "other", "steps": ["welcome", "connect"]}';
        await harness.engine.finishStep('how_it_rings');

        expect(harness.repository.pinned?.id, '2026-10-b');
        expect(harness.engine.runningFlow().id, '2026-10-b');
      },
    );

    test(
      'a remote flow that was in hand at Get started is the one pinned',
      () async {
        gate.json = _valid;

        await harness.engine.finishStep('welcome');

        expect(harness.repository.pinned?.id, '2026-10-b');
      },
    );
  });
}
