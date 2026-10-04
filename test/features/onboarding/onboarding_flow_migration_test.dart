import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/onboarding_flow_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // What each name the old enum saved resumes at, without and with a saved
  // server connection. No permission is granted and no topic exists.
  const cases = <String, (String, String)>{
    'welcome': ('/onboarding/welcome', '/onboarding/welcome'),
    'howItRings': ('/onboarding/connect', '/onboarding'),
    'permissions': ('/onboarding/connect', '/onboarding'),
    'widgets': ('/onboarding/connect', '/onboarding'),
    'connect': ('/onboarding/connect', '/onboarding'),
    'test': ('/onboarding/connect', '/onboarding'),
  };

  for (final MapEntry(key: legacy, value: (fresh, connected))
      in cases.entries) {
    for (final hasConnection in [false, true]) {
      test('old step "$legacy", '
          '${hasConnection ? 'with' : 'without'} a saved connection', () async {
        final h = EngineHarness(
          facts: FakeOnboardingStepFacts(connected: hasConnection),
          repository: FakeOnboardingFlowRepository(legacyStep: legacy),
        );

        final next = await h.engine.resume();

        expect(next.route, hasConnection ? connected : fresh);
        expect(h.repository.legacyStep, isNull);
        expect(h.repository.pinned, BundledOnboardingFlows.defaultFlow);
        expect(
          h.repository.completed,
          legacy == 'welcome' ? isEmpty : {'welcome', 'how_it_rings'},
        );
      });
    }
  }

  test('connected, with permissions, resumes at the first topic', () async {
    final h = EngineHarness(
      facts: FakeOnboardingStepFacts(connected: true, permissions: true),
      repository: FakeOnboardingFlowRepository(legacyStep: 'test'),
    );

    expect((await h.engine.resume()).route, '/onboarding/first-topic');
  });

  test('a name the old enum never had is treated as past the intro', () async {
    final h = EngineHarness(
      repository: FakeOnboardingFlowRepository(legacyStep: 'nonsense'),
    );

    expect((await h.engine.resume()).route, '/onboarding/connect');
  });

  test('a second run changes nothing', () async {
    final h = EngineHarness(
      facts: FakeOnboardingStepFacts(connected: true),
      repository: FakeOnboardingFlowRepository(legacyStep: 'connect'),
    );
    final first = await h.engine.resume();
    final writes = h.repository.writes;
    final pinned = h.repository.pinned;
    final completed = h.repository.completed;

    await h.engine.migrateLegacyStep();
    final second = await h.engine.resume();

    expect(second.route, first.route);
    expect(h.repository.writes, writes);
    expect(h.repository.pinned, pinned);
    expect(h.repository.completed, completed);
  });

  test('a flow that is already pinned is kept, and the old key goes', () async {
    final h = EngineHarness(
      repository: FakeOnboardingFlowRepository(
        pinned: BundledOnboardingFlows.legacy,
        completed: {'welcome'},
        legacyStep: 'test',
      ),
    );

    final next = await h.engine.resume();

    expect(h.repository.pinned, BundledOnboardingFlows.legacy);
    expect(h.repository.completed, {'welcome'});
    expect(h.repository.legacyStep, isNull);
    expect(next.route, '/onboarding/how-it-rings');
  });

  test('no old key means no migration', () async {
    final h = EngineHarness();

    await h.engine.migrateLegacyStep();

    expect(h.repository.writes, 0);
  });

  group('on real prefs', () {
    test('the old key is removed and the new ones written', () async {
      SharedPreferences.setMockInitialValues({'onboarding_step': 'connect'});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsOnboardingFlowRepository(prefs);
      final h = EngineHarness(
        facts: FakeOnboardingStepFacts(connected: true),
        store: store,
      );
      expect(store.readLegacyStep(), 'connect');

      final next = await h.engine.resume();

      expect(next.route, '/onboarding');
      expect(prefs.containsKey('onboarding_step'), isFalse);
      expect(prefs.getString('onboarding_flow_id'), '2026-10-a');
      expect(
        prefs.getStringList('onboarding_flow_steps'),
        BundledOnboardingFlows.defaultFlow.steps,
      );
      expect(prefs.getStringList('onboarding_flow_completed'), [
        'welcome',
        'how_it_rings',
      ]);

      // Completing setup clears all three.
      await h.engine.finishStep('permissions');
      await h.engine.finishStep('first_topic');
      await h.engine.finishStep('real_ring');
      expect((await h.engine.finishStep('hook_up')).isHome, isTrue);
      expect(
        prefs.getKeys().where((key) => key.startsWith('onboarding_flow')),
        isEmpty,
      );
    });
  });
}
