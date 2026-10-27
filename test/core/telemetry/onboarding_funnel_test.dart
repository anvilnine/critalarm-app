import 'dart:convert';

import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Behaves like the Firebase gate: an event is dropped unless collection is
/// on. Every call of any kind is written down.
class _Gate extends NoopTelemetryGate {
  _Gate();

  final calls = <String>[];
  final sent = <(String, Map<String, Object?>)>[];
  bool enabled = false;

  @override
  Future<void> initialize() async => calls.add('initialize');

  @override
  Future<void> setAnalyticsEnabled(bool enabled) async {
    calls.add('setAnalyticsEnabled');
    this.enabled = enabled;
  }

  @override
  Future<void> setCrashlyticsEnabled(bool enabled) async =>
      calls.add('setCrashlyticsEnabled');

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async {
    calls.add('logEvent');
    if (!enabled) return;
    sent.add((name, Map<String, Object?>.of(parameters ?? {})));
  }
}

class _Clock {
  DateTime now = DateTime.utc(2026, 10, 5, 9);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

const _steps = {'welcome', 'how_it_rings', 'connect', 'first_topic', 'hook_up'};
const _flow = '2026-10-a';

void main() {
  late SharedPreferences prefs;
  late _Gate gate;
  late _Clock clock;

  OnboardingFunnel build() => OnboardingFunnel(
    prefs: prefs,
    gate: gate,
    stepIds: _steps,
    clock: clock.call,
  );

  List<dynamic>? stored() {
    final raw = prefs.getString(OnboardingFunnel.bufferKey);
    return raw == null ? null : jsonDecode(raw) as List<dynamic>;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gate = _Gate();
    clock = _Clock();
  });

  group('before an answer', () {
    test('nothing is sent and no analytics call is made', () async {
      final funnel = build();
      await funnel.start(analyticsOn: false);
      for (final step in _steps) {
        await funnel.stepViewed(step, _flow);
        clock.advance(const Duration(seconds: 3));
        await funnel.stepCompleted(step, _flow);
      }

      expect(gate.calls, isEmpty);
      expect(gate.sent, isEmpty);
      expect(stored(), hasLength(_steps.length * 2));
      expect(funnel.state, OnboardingFunnelState.unanswered);
    });

    test('a launch with analytics off and no answer calls nothing', () async {
      await build().stepViewed('welcome', _flow);
      final next = build();
      await next.start(analyticsOn: false);

      expect(gate.calls, isEmpty);
      expect(stored(), hasLength(1));
    });
  });

  group('opting in', () {
    test(
      'sends the waiting events in order, once, then empties the buffer',
      () async {
        final funnel = build();
        await funnel.stepViewed('welcome', _flow);
        clock.advance(const Duration(seconds: 2));
        await funnel.stepCompleted('welcome', _flow);
        clock.advance(const Duration(milliseconds: 40));
        await funnel.stepViewed('how_it_rings', _flow);
        expect(gate.sent, isEmpty);

        await funnel.answered(isOn: true);

        expect(gate.sent.map((e) => e.$1), [
          AnalyticsEvents.onboardingStepViewed,
          AnalyticsEvents.onboardingStepCompleted,
          AnalyticsEvents.onboardingStepViewed,
        ]);
        expect(gate.sent.map((e) => e.$2['step']), [
          'welcome',
          'welcome',
          'how_it_rings',
        ]);
        expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);

        await funnel.answered(isOn: true);
        expect(gate.sent, hasLength(3));
      },
    );

    test('later events go straight through the gate', () async {
      final funnel = build();
      await funnel.stepViewed('welcome', _flow);
      await funnel.answered(isOn: true);
      gate.sent.clear();

      clock.advance(const Duration(seconds: 1));
      await funnel.stepCompleted('hook_up', _flow);

      expect(gate.sent, hasLength(1));
      expect(gate.sent.single.$1, AnalyticsEvents.onboardingStepCompleted);
      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
    });

    test('a launch with analytics already on sends what was waiting', () async {
      await build().stepViewed('welcome', _flow);
      gate.enabled = true;

      await build().start(analyticsOn: true);

      expect(gate.sent, hasLength(1));
      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
    });
  });

  group('opting out', () {
    test('deletes the buffer, sends nothing, buffers nothing', () async {
      final funnel = build();
      await funnel.stepViewed('welcome', _flow);
      await funnel.stepCompleted('welcome', _flow);

      await funnel.answered(isOn: false);
      await funnel.stepViewed('how_it_rings', _flow);

      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
      expect(gate.calls, isEmpty);
      expect(funnel.state, OnboardingFunnelState.optedOut);
    });

    test(
      'analytics switched off later deletes what had not been sent',
      () async {
        final funnel = build();
        await funnel.answered(isOn: true);
        // The user is opted in, and a leftover list is on disk (a crash
        // between writing and sending).
        await prefs.setString(
          OnboardingFunnel.bufferKey,
          jsonEncode([
            {
              'k': 'v',
              'step': 'welcome',
              'flow_id': _flow,
              'ms': 0,
              'at': clock.now.millisecondsSinceEpoch,
            },
          ]),
        );
        gate.calls.clear();
        gate.sent.clear();

        await build().start(analyticsOn: false);

        expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
        expect(gate.sent, isEmpty);
        expect(gate.calls, isEmpty);
      },
    );
  });

  group('no answer for a week', () {
    test('the events are still there at 6 days 23 hours', () async {
      final funnel = build();
      await funnel.stepViewed('welcome', _flow);
      clock.advance(const Duration(days: 6, hours: 23));

      await build().start(analyticsOn: false);

      expect(stored(), hasLength(1));
      expect(funnel.state, OnboardingFunnelState.unanswered);
    });

    test(
      'they are deleted at 7 days and 1 second, and nothing is sent',
      () async {
        final funnel = build();
        await funnel.stepViewed('welcome', _flow);
        clock.advance(const Duration(days: 7, seconds: 1));

        await build().start(analyticsOn: false);

        expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
        expect(gate.calls, isEmpty);
        expect(funnel.state, OnboardingFunnelState.expired);
      },
    );

    test('adding an event checks the age too', () async {
      final funnel = build();
      await funnel.stepViewed('welcome', _flow);
      clock.advance(const Duration(days: 7, seconds: 1));

      await funnel.stepViewed('how_it_rings', _flow);

      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
      expect(gate.calls, isEmpty);
    });

    test(
      'nothing is buffered after that, and a late opt-in sends nothing old',
      () async {
        final funnel = build();
        await funnel.stepViewed('welcome', _flow);
        clock.advance(const Duration(days: 8));
        await funnel.start(analyticsOn: false);

        await funnel.stepViewed('connect', _flow);
        expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);

        await funnel.answered(isOn: true);
        expect(gate.sent, isEmpty);
      },
    );
  });

  group('what an event holds', () {
    test('exactly step, flow_id and ms_since_previous', () async {
      final funnel = build();
      await funnel.answered(isOn: true);
      await funnel.stepViewed('first_topic', _flow);
      await funnel.stepCompleted('first_topic', _flow);

      expect(gate.sent, hasLength(2));
      for (final (_, params) in gate.sent) {
        expect(params.keys.toSet(), {'step', 'flow_id', 'ms_since_previous'});
        expect(params['step'], 'first_topic');
        expect(params['flow_id'], _flow);
      }
    });

    test(
      'buffered events keep the same three parameters on the way out',
      () async {
        final funnel = build();
        await funnel.stepViewed('first_topic', _flow);
        await funnel.answered(isOn: true);

        expect(gate.sent.single.$2.keys.toSet(), {
          'step',
          'flow_id',
          'ms_since_previous',
        });
      },
    );

    test('ms_since_previous is 0 first, then a whole number', () async {
      final funnel = build();
      await funnel.answered(isOn: true);
      await funnel.stepViewed('welcome', _flow);
      clock.advance(const Duration(milliseconds: 1500));
      await funnel.stepCompleted('welcome', _flow);
      clock.advance(const Duration(milliseconds: 250));
      await funnel.stepViewed('how_it_rings', _flow);

      expect(gate.sent.map((e) => e.$2['ms_since_previous']), [0, 1500, 250]);
      expect(
        gate.sent.map((e) => e.$2['ms_since_previous']),
        everyElement(isA<int>()),
      );
    });

    test('a new app run starts at 0 again', () async {
      final first = build();
      await first.answered(isOn: true);
      await first.stepViewed('welcome', _flow);
      clock.advance(const Duration(minutes: 5));

      await build().stepViewed('connect', _flow);

      expect(gate.sent.last.$2['ms_since_previous'], 0);
    });

    test('a flow id outside the allowed pattern drops the event', () async {
      final funnel = build();
      for (final bad in [
        '',
        'two words',
        'has/slash',
        'a' * 41,
        'tokén',
        'https://example.test',
      ]) {
        await funnel.stepViewed('welcome', bad);
      }
      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);

      await funnel.stepViewed('welcome', 'a' * 40);
      await funnel.stepViewed('welcome', 'A-z_0.9');
      expect(stored(), hasLength(2));
    });

    test('a step that is not in the registry drops the event', () async {
      final funnel = build();
      await funnel.stepViewed('my_secret_topic', _flow);
      await funnel.stepCompleted('', _flow);

      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
      expect(gate.calls, isEmpty);
    });
  });

  group('replay', () {
    test('records and buffers nothing, before or after an opt-in', () async {
      final funnel = build();
      await funnel.stepViewed('welcome', _flow, isReplay: true);
      await funnel.stepCompleted('welcome', _flow, isReplay: true);
      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
      expect(gate.calls, isEmpty);

      await funnel.answered(isOn: true);
      gate.sent.clear();
      await funnel.stepViewed('connect', _flow, isReplay: true);
      expect(gate.sent, isEmpty);
    });

    test('a replay does not move the clock for the next real event', () async {
      final funnel = build();
      await funnel.answered(isOn: true);
      await funnel.stepViewed('welcome', _flow);
      clock.advance(const Duration(seconds: 10));
      await funnel.stepViewed('connect', _flow, isReplay: true);
      clock.advance(const Duration(seconds: 10));
      await funnel.stepViewed('connect', _flow);

      expect(gate.sent.last.$2['ms_since_previous'], 20000);
    });
  });

  group('the offer step', () {
    const offer = <String, Object?>{
      'product': 'pro',
      'layout': 'hero',
      'use': 'servers',
      'flow_id': _flow,
    };

    test(
      'shown, closed and bought carry product, layout, use and flow id',
      () async {
        final funnel = build();
        await funnel.answered(isOn: true);
        await funnel.offerShown(
          product: 'pro',
          layout: 'hero',
          use: 'servers',
          flowId: _flow,
        );
        await funnel.offerClosed(
          product: 'pro',
          layout: 'hero',
          use: 'servers',
          flowId: _flow,
        );
        await funnel.offerBought(
          product: 'pro',
          layout: 'hero',
          use: 'servers',
          flowId: _flow,
        );

        expect(gate.sent.map((e) => e.$1), [
          AnalyticsEvents.onboardingOfferShown,
          AnalyticsEvents.onboardingOfferClosed,
          AnalyticsEvents.onboardingOfferBought,
        ]);
        expect(gate.sent.map((e) => e.$2), everyElement(offer));
      },
    );

    test('every answer of the closed set is accepted', () async {
      final funnel = build();
      await funnel.answered(isOn: true);
      const words = ['servers', 'homelab', 'jobs', 'home', 'other'];
      for (final word in words) {
        await funnel.offerShown(
          product: 'hosted',
          layout: 'reel',
          use: word,
          flowId: _flow,
        );
      }

      expect(gate.sent.map((e) => e.$2['use']), words);
    });

    test('they wait with the step events and go in order', () async {
      final funnel = build();
      await funnel.stepViewed('welcome', _flow);
      await funnel.offerShown(
        product: 'hosted',
        layout: 'sheet',
        use: 'homelab',
        flowId: _flow,
      );
      await funnel.offerBought(
        product: 'hosted',
        layout: 'sheet',
        use: 'homelab',
        flowId: _flow,
      );
      expect(gate.calls, isEmpty);
      expect(stored(), hasLength(3));

      // A new app run reads the same list back.
      await build().answered(isOn: true);
      expect(gate.sent.map((e) => e.$1), [
        AnalyticsEvents.onboardingStepViewed,
        AnalyticsEvents.onboardingOfferShown,
        AnalyticsEvents.onboardingOfferBought,
      ]);
      expect(gate.sent[1].$2, {
        'product': 'hosted',
        'layout': 'sheet',
        'use': 'homelab',
        'flow_id': _flow,
      });
      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
    });

    test('an opt-out drops them', () async {
      final funnel = build();
      await funnel.offerShown(
        product: 'pro',
        layout: 'hero',
        use: 'jobs',
        flowId: _flow,
      );
      await funnel.answered(isOn: false);
      await funnel.offerClosed(
        product: 'pro',
        layout: 'hero',
        use: 'jobs',
        flowId: _flow,
      );

      expect(gate.sent, isEmpty);
      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
    });

    test('a replay records nothing', () async {
      final funnel = build();
      await funnel.answered(isOn: true);
      gate.sent.clear();
      await funnel.offerShown(
        product: 'pro',
        layout: 'hero',
        use: 'home',
        flowId: _flow,
        isReplay: true,
      );
      await funnel.offerBought(
        product: 'pro',
        layout: 'hero',
        use: 'home',
        flowId: _flow,
        isReplay: true,
      );
      expect(gate.sent, isEmpty);
    });

    test(
      'an unknown product, layout, use or flow id drops the event',
      () async {
        final funnel = build();
        Future<void> shown({
          String product = 'pro',
          String layout = 'hero',
          String use = 'servers',
          String flowId = _flow,
        }) => funnel.offerShown(
          product: product,
          layout: layout,
          use: use,
          flowId: flowId,
        );
        await shown(product: 'gold');
        await shown(layout: 'nope');
        await shown(use: 'Servers');
        await shown(use: '');
        await shown(use: 'prod-db');
        // Skipped is a word of the pick event, not of an answer.
        await shown(use: 'skipped');
        await shown(flowId: 'a b');

        expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
        expect(gate.calls, isEmpty);
      },
    );

    test('they do not move the clock of the step events', () async {
      final funnel = build();
      await funnel.answered(isOn: true);
      await funnel.stepViewed('welcome', _flow);
      clock.advance(const Duration(seconds: 4));
      await funnel.offerShown(
        product: 'pro',
        layout: 'hero',
        use: 'servers',
        flowId: _flow,
      );
      clock.advance(const Duration(seconds: 4));
      await funnel.stepViewed('connect', _flow);

      expect(gate.sent.last.$2['ms_since_previous'], 8000);
    });

    test('a row buffered before the answer was added still reads', () async {
      await prefs.setString(
        OnboardingFunnel.bufferKey,
        jsonEncode([
          {
            'k': 'os',
            'product': 'pro',
            'layout': 'hero',
            'flow_id': _flow,
            'at': clock.now.millisecondsSinceEpoch,
          },
          {
            'k': 'ob',
            'product': 'hosted',
            'layout': 'reel',
            'use': 'jobs',
            'flow_id': _flow,
            'at': clock.now.millisecondsSinceEpoch,
          },
        ]),
      );
      await build().answered(isOn: true);

      expect(gate.sent.map((e) => e.$1), [
        AnalyticsEvents.onboardingOfferShown,
        AnalyticsEvents.onboardingOfferBought,
      ]);
      // The old row has no answer behind it, so it goes as other.
      expect(gate.sent[0].$2, {
        'product': 'pro',
        'layout': 'hero',
        'use': 'other',
        'flow_id': _flow,
      });
      expect(gate.sent[1].$2['use'], 'jobs');
    });

    test('a buffered row waits as written, with its answer', () async {
      final funnel = build();
      await funnel.offerClosed(
        product: 'hosted',
        layout: 'reel',
        use: 'home',
        flowId: _flow,
      );

      expect(stored(), [
        {
          'k': 'oc',
          'product': 'hosted',
          'layout': 'reel',
          'use': 'home',
          'flow_id': _flow,
          'at': clock.now.millisecondsSinceEpoch,
        },
      ]);
    });

    test(
      'a stored offer row that is not as written deletes the list',
      () async {
        for (final row in [
          {
            'k': 'os',
            'product': 'gold',
            'layout': 'hero',
            'use': 'servers',
            'flow_id': _flow,
            'at': 1,
          },
          // An answer outside the closed set.
          {
            'k': 'os',
            'product': 'pro',
            'layout': 'hero',
            'use': 'skipped',
            'flow_id': _flow,
            'at': 1,
          },
          {
            'k': 'os',
            'product': 'pro',
            'layout': 'hero',
            'use': 7,
            'flow_id': _flow,
            'at': 1,
          },
          // A field that is not part of the event.
          {
            'k': 'os',
            'product': 'pro',
            'layout': 'hero',
            'use': 'home',
            'extra': 1,
            'flow_id': _flow,
            'at': 1,
          },
        ]) {
          await prefs.setString(OnboardingFunnel.bufferKey, jsonEncode([row]));
          await build().answered(isOn: true);

          expect(gate.sent, isEmpty, reason: '$row');
          expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
        }
      },
    );
  });

  group('the use step', () {
    test('a pick waits with no answer, and nothing is sent', () async {
      final funnel = build();
      await funnel.usePicked(use: 'servers', flowId: _flow);

      expect(gate.calls, isEmpty);
      expect(stored(), [
        {
          'k': 'up',
          'use': 'servers',
          'flow_id': _flow,
          'at': clock.now.millisecondsSinceEpoch,
        },
      ]);
    });

    test('goes on an opt-in, in order, with the use and the flow id', () async {
      final funnel = build();
      await funnel.stepViewed('welcome', _flow);
      await funnel.usePicked(use: 'homelab', flowId: _flow);
      await funnel.usePicked(use: 'skipped', flowId: _flow);
      await build().answered(isOn: true);

      expect(gate.sent.map((e) => e.$1), [
        AnalyticsEvents.onboardingStepViewed,
        AnalyticsEvents.onboardingUsePicked,
        AnalyticsEvents.onboardingUsePicked,
      ]);
      expect(gate.sent[1].$2, {'use': 'homelab', 'flow_id': _flow});
      expect(gate.sent[2].$2, {'use': 'skipped', 'flow_id': _flow});
      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
    });

    test('goes straight through once opted in', () async {
      final funnel = build();
      await funnel.answered(isOn: true);
      await funnel.usePicked(use: 'home', flowId: _flow);

      expect(gate.sent.single.$2, {'use': 'home', 'flow_id': _flow});
    });

    test('an opt-out drops it', () async {
      final funnel = build();
      await funnel.usePicked(use: 'jobs', flowId: _flow);
      await funnel.answered(isOn: false);
      await funnel.usePicked(use: 'other', flowId: _flow);

      expect(gate.sent, isEmpty);
      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
    });

    test('a replay records nothing', () async {
      final funnel = build();
      await funnel.usePicked(use: 'servers', flowId: _flow, isReplay: true);
      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);

      await funnel.answered(isOn: true);
      await funnel.usePicked(use: 'servers', flowId: _flow, isReplay: true);
      expect(gate.sent, isEmpty);
    });

    test('every word of the closed set is accepted', () async {
      final funnel = build();
      await funnel.answered(isOn: true);
      const words = ['servers', 'homelab', 'jobs', 'home', 'other', 'skipped'];
      for (final word in words) {
        await funnel.usePicked(use: word, flowId: _flow);
      }

      expect(gate.sent.map((e) => e.$2['use']), words);
    });

    test('an unknown use or flow id is dropped', () async {
      final funnel = build();
      await funnel.usePicked(use: 'Servers', flowId: _flow);
      await funnel.usePicked(use: '', flowId: _flow);
      await funnel.usePicked(use: 'prod-db', flowId: _flow);
      await funnel.usePicked(use: 'servers', flowId: 'a b');
      await funnel.usePicked(use: 'servers', flowId: '');

      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
      expect(gate.calls, isEmpty);
    });

    test('it does not move the clock of the step events', () async {
      final funnel = build();
      await funnel.answered(isOn: true);
      await funnel.stepViewed('welcome', _flow);
      clock.advance(const Duration(seconds: 4));
      await funnel.usePicked(use: 'servers', flowId: _flow);
      clock.advance(const Duration(seconds: 4));
      await funnel.stepViewed('connect', _flow);

      expect(gate.sent.last.$2['ms_since_previous'], 8000);
    });

    test('a stored row that is not as written deletes the list', () async {
      for (final row in [
        {'k': 'up', 'use': 'gold', 'flow_id': _flow, 'at': 1},
        {'k': 'up', 'use': 'home', 'flow_id': _flow, 'at': 1, 'extra': 1},
        {'k': 'up', 'flow_id': _flow, 'at': 1},
      ]) {
        await prefs.setString(OnboardingFunnel.bufferKey, jsonEncode([row]));
        await build().answered(isOn: true);

        expect(gate.sent, isEmpty, reason: '$row');
        expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
      }
    });
  });

  group('the cap', () {
    test('holds at 100 and drops the new event, never an old one', () async {
      final funnel = build();
      for (var i = 0; i < 100; i++) {
        clock.advance(const Duration(seconds: 1));
        await funnel.stepViewed('welcome', _flow);
      }
      final before = prefs.getString(OnboardingFunnel.bufferKey);
      expect(stored(), hasLength(100));

      await funnel.stepCompleted('hook_up', _flow);
      await funnel.stepViewed('connect', _flow);

      expect(prefs.getString(OnboardingFunnel.bufferKey), before);
      expect(stored(), hasLength(100));
      expect(gate.calls, isEmpty);
    });
  });

  group('a buffer that is not ours', () {
    final badBuffers = <String, String>{
      'not json': '{{{',
      'not a list': '{"k":"v"}',
      'a row that is not a map': '[1]',
      'an extra field': jsonEncode([
        {
          'k': 'v',
          'step': 'welcome',
          'flow_id': _flow,
          'ms': 0,
          'at': 1,
          'topic': 'prod-alerts',
        },
      ]),
      'an unknown step': jsonEncode([
        {'k': 'v', 'step': 'prod-alerts', 'flow_id': _flow, 'ms': 0, 'at': 1},
      ]),
      'a flow id that does not fit': jsonEncode([
        {'k': 'v', 'step': 'welcome', 'flow_id': 'a b', 'ms': 0, 'at': 1},
      ]),
      'a negative time': jsonEncode([
        {'k': 'v', 'step': 'welcome', 'flow_id': _flow, 'ms': -1, 'at': 1},
      ]),
      'an unknown kind': jsonEncode([
        {'k': 'x', 'step': 'welcome', 'flow_id': _flow, 'ms': 0, 'at': 1},
      ]),
    };

    for (final entry in badBuffers.entries) {
      test('${entry.key} is deleted on opt-in and nothing is sent', () async {
        await prefs.setString(OnboardingFunnel.bufferKey, entry.value);

        await build().answered(isOn: true);

        expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
        expect(gate.sent, isEmpty);
      });
    }

    test('it is deleted at launch too', () async {
      await prefs.setString(OnboardingFunnel.bufferKey, '{{{');

      await build().start(analyticsOn: false);

      expect(prefs.containsKey(OnboardingFunnel.bufferKey), isFalse);
      expect(gate.calls, isEmpty);
    });
  });

  test('two events in a row both reach the buffer', () async {
    final funnel = build();
    final both = Future.wait([
      funnel.stepCompleted('welcome', _flow),
      funnel.stepViewed('how_it_rings', _flow),
    ]);
    await both;

    expect(stored(), hasLength(2));
  });

  test('a gate that throws never reaches the caller', () async {
    final funnel = OnboardingFunnel(
      prefs: prefs,
      gate: _ThrowingGate(),
      stepIds: _steps,
      clock: clock.call,
    );
    await funnel.stepViewed('welcome', _flow);

    await funnel.answered(isOn: true);
    await funnel.stepViewed('connect', _flow);
  });
}

class _ThrowingGate extends NoopTelemetryGate {
  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async => throw StateError('offline');
}
