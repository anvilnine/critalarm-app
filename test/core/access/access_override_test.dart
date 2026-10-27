import 'dart:async';

import 'package:critalarm/core/access/access_override.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/features/pro_pack/data/prefs_pro_pack_dev_switch.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'access_fakes.dart';
import 'feature_table_test.dart' show featureTruth, truthHoldings;

/// The real sources, the override in front of them, and the two managers
/// on top: the same stack the app builds, with sources a test sets by
/// hand.
class _Stack {
  _Stack(
    this.override, {
    HoldingState hosted = HoldingState.notHeld,
    HoldingState pro = HoldingState.notHeld,
    ServerMode? session = ServerMode.hosted,
  }) : realHosted = FakeHoldingSource(Holding.hosted, hosted),
       realPro = FakeHoldingSource(Holding.pro, pro),
       session = ValueNotifier(session) {
    sources = [
      OverriddenHoldingSource(realHosted, override: override),
      OverriddenHoldingSource(realPro, override: override),
    ];
    holdings = Holdings(sources);
    mode = OverriddenServerMode(this.session, override: override);
    features = FeatureAccess(holdings: holdings, serverMode: mode.value);
    // The same line the composition root has.
    mode.changes.addListener(() => features.setServerMode(mode.value));
  }

  final AccessOverride override;
  final FakeHoldingSource realHosted;
  final FakeHoldingSource realPro;
  final ValueNotifier<ServerMode?> session;
  late final List<OverriddenHoldingSource> sources;
  late final Holdings holdings;
  late final OverriddenServerMode mode;
  late final FeatureAccess features;

  Map<AppFeature, FeatureDecision> get decisions => {
    for (final feature in AppFeature.values) feature: features.decide(feature),
  };

  Future<void> dispose() async {
    await features.dispose();
    await holdings.dispose();
  }
}

Future<DevAccessSwitches> _switches([
  Map<String, Object> seed = const {},
]) async {
  SharedPreferences.setMockInitialValues(seed);
  return DevAccessSwitches(await SharedPreferences.getInstance());
}

/// The truth table's column for what a preset forces, or null when the
/// preset has a state the table has no column for.
int? _column(AccessPreset preset, {required bool isOwnServer}) {
  // Holds the same holdings as Free and differs only in the plan read.
  if (preset.holdsPlanRead) return null;
  final states = preset.holdings.values.toSet();
  if (states.contains(HoldingState.pending) ||
      states.contains(HoldingState.unknown)) {
    return null;
  }
  final held = {
    for (final entry in preset.holdings.entries)
      if (entry.value == HoldingState.held) entry.key,
  };
  final index = truthHoldings.indexWhere((set) => setEquals(set, held));
  return index + (isOwnServer ? 4 : 0);
}

/// Every switch a developer build could have saved, all of them forcing.
const Map<String, Object> _everythingForced = {
  'dev.access.hosted': 'held',
  'dev.access.pro': 'held',
  'dev.access.server': 'ownServer',
  'dev.pro_mode': true,
  'dev.pro_pack': true,
};

void main() {
  group('a store build', () {
    test('is what this test run was compiled with', () {
      expect(
        buildSkipsPaywall,
        isFalse,
        reason: 'flutter test passes no SKIP_PAYWALL dart-define',
      );
      expect(appAccessOverride, isA<NoAccessOverride>());
    });

    test('forces nothing, whatever the switches say', () async {
      final switches = await _switches(_everythingForced);
      // The switches themselves do say so: this is a real forced state.
      expect(switches.forcedState(Holding.hosted), HoldingState.held);
      expect(switches.forcedState(Holding.pro), HoldingState.held);
      expect(switches.serverMode, ServerModeChoice.ownServer);

      appAccessOverride.watch(switches);

      expect(appAccessOverride.listenable, isNull);
      for (final holding in Holding.values) {
        expect(appAccessOverride.forcedState(holding), isNull);
      }
      expect(appAccessOverride.serverMode, ServerModeChoice.real);
      for (final real in [null, ...ServerMode.values]) {
        expect(appAccessOverride.serverModeOver(real), real);
      }
    });

    test('the wrappers answer with the real sources, in every state', () async {
      final switches = await _switches(_everythingForced);
      // No override handed in: the build's own, as the app does it.
      appAccessOverride.watch(switches);
      for (final real in HoldingState.values) {
        final source = FakeHoldingSource(Holding.pro, real);
        final wrapped = OverriddenHoldingSource(source);
        expect(wrapped.state, real);
        expect(wrapped.realState, real);
        expect(identical(wrapped.changes, source.changes), isTrue);
      }
      for (final real in [null, ...ServerMode.values]) {
        final session = ValueNotifier<ServerMode?>(real);
        final mode = OverriddenServerMode(session);
        expect(mode.value, real);
        expect(identical(mode.changes, session), isTrue);
      }
    });

    test('the plan read is never held, whatever a preset says', () async {
      final switches = await _switches({'dev.access.hold_plan_read': true});
      expect(switches.holdsPlanRead, isTrue);
      const override = NoAccessOverride();
      final stack = _Stack(override..watch(switches));
      addTearDown(stack.dispose);
      await switches.apply(AccessPreset.planReading);
      await stack.holdings.ready;
      await stack.features.ready;
      expect(stack.features.isPlanRead, isTrue);
    });

    test('a change of the switches moves no decision', () async {
      final switches = await _switches();
      const override = NoAccessOverride();
      final stack = _Stack(override..watch(switches));
      addTearDown(stack.dispose);
      final before = stack.decisions;
      final heard = <AppFeature>[];
      stack.features.changes.listen(heard.add);

      for (final preset in AccessPreset.values) {
        await switches.apply(preset);
        for (final choice in ServerModeChoice.values) {
          await switches.setServerMode(choice);
          expect(stack.decisions, before, reason: '$preset, $choice');
          expect(stack.holdings.held, isEmpty);
        }
      }
      await settle();
      expect(heard, isEmpty);
    });
  });

  group('a build that skips the paywall', () {
    late DevAccessSwitches switches;
    late DevAccessOverride override;

    setUp(() async {
      switches = await _switches();
      override = DevAccessOverride()..watch(switches);
    });

    group('presets against the truth table', () {
      for (final preset in AccessPreset.values) {
        for (final isOwnServer in [false, true]) {
          final column = _column(preset, isOwnServer: isOwnServer);
          if (column == null || preset == AccessPreset.real) continue;
          final where = isOwnServer ? 'own server' : 'cloud';

          test('${preset.name} on $where is column $column', () async {
            // The real sources say the opposite of the preset, so a pass
            // is the override's doing.
            final opposite = preset.holdings.map(
              (holding, state) => MapEntry(
                holding,
                state == HoldingState.held
                    ? HoldingState.notHeld
                    : HoldingState.held,
              ),
            );
            final stack = _Stack(
              override,
              hosted: opposite[Holding.hosted]!,
              pro: opposite[Holding.pro]!,
            );
            addTearDown(stack.dispose);

            await switches.apply(preset);
            await switches.setServerMode(
              isOwnServer ? ServerModeChoice.ownServer : ServerModeChoice.cloud,
            );

            for (final feature in AppFeature.values) {
              expect(
                stack.features.decide(feature),
                featureTruth[feature]![column],
                reason: feature.name,
              );
            }
          });
        }
      }

      test('every preset the table has a column for is checked', () {
        final checked = [
          for (final preset in AccessPreset.values)
            if (_column(preset, isOwnServer: false) != null &&
                preset != AccessPreset.real)
              preset,
        ];
        expect(checked, [
          AccessPreset.free,
          AccessPreset.hosted,
          AccessPreset.pro,
          AccessPreset.hostedAndPro,
        ]);
      });
    });

    group('plan still being read', () {
      test('answers as a phone that holds nothing', () async {
        final stack = _Stack(override, hosted: HoldingState.held);
        addTearDown(stack.dispose);
        await switches.apply(AccessPreset.planReading);

        expect(switches.preset, AccessPreset.planReading);
        expect(switches.holdsPlanRead, isTrue);
        for (final feature in AppFeature.values) {
          expect(
            stack.features.decide(feature),
            featureTruth[feature]![0],
            reason: feature.name,
          );
        }
      });

      test('holds ready open until it is released', () async {
        await switches.apply(AccessPreset.planReading);
        final stack = _Stack(override);
        addTearDown(stack.dispose);
        await settle();
        expect(stack.features.isPlanRead, isFalse);

        var isDone = false;
        unawaited(stack.features.ready.then((_) => isDone = true));
        await settle();
        expect(isDone, isFalse);
        expect(stack.features.isPlanRead, isFalse);

        // Another holding preset is a release.
        await switches.apply(AccessPreset.free);
        await settle();
        expect(isDone, isTrue);
        expect(stack.features.isPlanRead, isTrue);
        expect(switches.holdsPlanRead, isFalse);
      });

      test('is told apart from Free, which has the same holdings', () async {
        await switches.apply(AccessPreset.free);
        expect(switches.preset, AccessPreset.free);
        await switches.apply(AccessPreset.planReading);
        expect(switches.preset, AccessPreset.planReading);
        expect(switches.isAnyOn, isTrue);
      });

      test('is remembered, and Real releases it', () async {
        await switches.apply(AccessPreset.planReading);
        final again = DevAccessSwitches(await SharedPreferences.getInstance());
        expect(again.holdsPlanRead, isTrue);
        expect(again.preset, AccessPreset.planReading);

        await switches.releaseAll();
        expect(switches.holdsPlanRead, isFalse);
        expect(switches.isAnyOn, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().where((key) => key.startsWith('dev.')),
          isEmpty,
        );
      });

      test('forcing one holding on its own leaves the hold alone', () async {
        await switches.apply(AccessPreset.planReading);
        await switches.force(Holding.hosted, HoldingState.held);
        expect(switches.holdsPlanRead, isTrue);
        expect(switches.preset, isNull);
      });
    });

    test('purchase confirming: what Pro unlocks is open and marked', () async {
      final stack = _Stack(override);
      addTearDown(stack.dispose);
      await switches.apply(AccessPreset.purchaseConfirming);

      expect(stack.holdings.stateOf(Holding.pro), HoldingState.pending);
      expect(stack.holdings.stateOf(Holding.hosted), HoldingState.notHeld);
      for (final feature in AppFeature.values) {
        final decision = stack.features.decide(feature);
        if (featureTable[feature]!.unlockedBy.contains(Holding.pro)) {
          expect(
            decision,
            const FeatureDecision.confirming(Holding.pro),
            reason: feature.name,
          );
          expect(decision.isUsable, isTrue);
        } else {
          // Hosted is not held in this preset: the free column.
          expect(decision, featureTruth[feature]![0], reason: feature.name);
        }
      }
    });

    test('plan could not be read: nothing locks and nothing sells', () async {
      // The real sources say "not held", which would lock everything.
      final stack = _Stack(override);
      addTearDown(stack.dispose);
      await switches.apply(AccessPreset.planUnreadable);

      for (final holding in Holding.values) {
        expect(stack.holdings.isUnknown(holding), isTrue);
        expect(stack.holdings.holds(holding), isFalse);
        await expectLater(
          stack.holdings.holdsOnceReady(holding),
          throwsA(isA<HoldingUnreadable>()),
        );
      }
      for (final feature in AppFeature.values) {
        final decision = stack.features.decide(feature);
        expect(decision, isA<FeatureUnread>(), reason: feature.name);
        expect(decision, isNot(isA<FeatureLocked>()), reason: feature.name);
        expect(stack.features.can(feature), isTrue, reason: feature.name);
        await expectLater(
          stack.features.canOnceReady(feature),
          throwsA(isA<HoldingUnreadable>()),
          reason: feature.name,
        );
      }
    });

    test('a preset changes every decision at once, with no restart', () async {
      final stack = _Stack(override);
      addTearDown(stack.dispose);
      final heard = <AppFeature>[];
      final sets = <Set<Holding>>[];
      stack.features.changes.listen(heard.add);
      stack.holdings.stream.listen(sets.add);

      await switches.apply(AccessPreset.hostedAndPro);
      await settle();

      expect(heard.toSet(), AppFeature.values.toSet());
      expect(sets.last, {Holding.hosted, Holding.pro});
      for (final feature in AppFeature.values) {
        expect(stack.features.decide(feature), const FeatureDecision.open());
      }
    });

    test('release returns to what the real sources say', () async {
      final stack = _Stack(
        override,
        hosted: HoldingState.held,
        session: ServerMode.selfhosted,
      );
      addTearDown(stack.dispose);
      final real = stack.decisions;
      expect(real[AppFeature.appIcons], const FeatureDecision.open());

      await switches.apply(AccessPreset.free);
      await switches.setServerMode(ServerModeChoice.cloud);
      expect(
        stack.features.decide(AppFeature.appIcons),
        const FeatureDecision.locked(Holding.hosted),
      );
      // The source underneath was never touched.
      expect(stack.sources.first.realState, HoldingState.held);
      expect(stack.mode.realValue, ServerMode.selfhosted);

      await switches.releaseAll();
      expect(switches.isAnyOn, isFalse);
      expect(switches.preset, AccessPreset.real);
      expect(stack.decisions, real);
      expect(stack.features.serverMode, ServerMode.selfhosted);

      // And it follows the real source again from here on.
      stack.realHosted.set(HoldingState.notHeld);
      stack.session.value = ServerMode.hosted;
      expect(
        stack.features.decide(AppFeature.appIcons),
        const FeatureDecision.locked(Holding.hosted),
      );
    });

    test('one holding can be forced and the other left real', () async {
      final stack = _Stack(override, pro: HoldingState.held);
      addTearDown(stack.dispose);
      await switches.force(Holding.hosted, HoldingState.pending);

      expect(stack.holdings.stateOf(Holding.hosted), HoldingState.pending);
      expect(stack.holdings.stateOf(Holding.pro), HoldingState.held);
      expect(switches.preset, isNull);

      await switches.force(Holding.hosted, null);
      expect(stack.holdings.stateOf(Holding.hosted), HoldingState.notHeld);
    });

    group('the server mode', () {
      test('follows the session until it is forced', () async {
        final stack = _Stack(override, session: ServerMode.selfhosted);
        addTearDown(stack.dispose);
        expect(stack.features.isOwnServer, isTrue);

        await switches.setServerMode(ServerModeChoice.cloud);
        expect(stack.features.serverMode, ServerMode.hosted);
        expect(stack.features.isOwnServer, isFalse);

        await switches.setServerMode(ServerModeChoice.unknown);
        expect(stack.features.serverMode, isNull);

        // A connect underneath changes nothing while a mode is forced.
        stack.session.value = ServerMode.relay;
        expect(stack.features.serverMode, isNull);

        await switches.setServerMode(ServerModeChoice.ownServer);
        expect(stack.features.serverMode, ServerMode.selfhosted);

        await switches.setServerMode(ServerModeChoice.real);
        expect(stack.features.serverMode, ServerMode.relay);
      });

      test('a preset leaves it alone, and Real releases it', () async {
        await switches.setServerMode(ServerModeChoice.ownServer);
        for (final preset in AccessPreset.values) {
          if (preset == AccessPreset.real) continue;
          await switches.apply(preset);
          expect(switches.serverMode, ServerModeChoice.ownServer);
          expect(switches.preset, preset);
        }
        await switches.apply(AccessPreset.real);
        expect(switches.serverMode, ServerModeChoice.real);
      });
    });

    group('the two older toggles', () {
      test('the Hosted toggle is force held and release on the seam', () async {
        final stack = _Stack(override);
        addTearDown(stack.dispose);
        final toggle = DevProSwitch(switches);
        // What the three readers outside Holdings still listen to.
        final older = DevProOverride()..watch(toggle);

        await toggle.setPro(isPro: true);
        expect(switches.forcedState(Holding.hosted), HoldingState.held);
        expect(stack.holdings.stateOf(Holding.hosted), HoldingState.held);
        expect(older.isForcingPro, isTrue);
        expect(switches.preset, isNull);

        await toggle.setPro(isPro: false);
        expect(switches.forcedState(Holding.hosted), isNull);
        expect(stack.holdings.stateOf(Holding.hosted), HoldingState.notHeld);
        expect(older.isForcingPro, isFalse);
      });

      test('the Pro toggle is force held and release on the seam', () async {
        final stack = _Stack(override);
        addTearDown(stack.dispose);
        final toggle = PrefsProPackDevSwitch(switches);
        final older = DevProPackOverride()..watch(toggle);

        await toggle.setHeld(isHeld: true);
        expect(switches.forcedState(Holding.pro), HoldingState.held);
        expect(stack.holdings.stateOf(Holding.pro), HoldingState.held);
        expect(older.isForcing, isTrue);

        await toggle.setHeld(isHeld: false);
        expect(switches.forcedState(Holding.pro), isNull);
        expect(stack.holdings.stateOf(Holding.pro), HoldingState.notHeld);
        expect(older.isForcing, isFalse);
      });

      test('both toggles on is the Hosted and Pro preset', () async {
        final hosted = DevProSwitch(switches);
        final pro = PrefsProPackDevSwitch(switches);
        await hosted.setPro(isPro: true);
        await pro.setHeld(isHeld: true);
        expect(switches.preset, AccessPreset.hostedAndPro);
      });

      test(
        'a preset moves the toggles, and they tell their listeners',
        () async {
          final hosted = DevProSwitch(switches);
          final pro = PrefsProPackDevSwitch(switches);
          final seen = <(bool, bool)>[];
          hosted.addListener(() => seen.add((hosted.value, pro.value)));

          await switches.apply(AccessPreset.hosted);
          await switches.apply(AccessPreset.pro);
          // Forced to something other than held reads as off.
          await switches.apply(AccessPreset.purchaseConfirming);

          expect(seen, [(true, false), (false, true), (false, false)]);
        },
      );
    });

    group('is remembered', () {
      test('across a restart', () async {
        await switches.apply(AccessPreset.purchaseConfirming);
        await switches.setServerMode(ServerModeChoice.ownServer);

        final again = DevAccessSwitches(await SharedPreferences.getInstance());
        expect(again.forcedState(Holding.hosted), HoldingState.notHeld);
        expect(again.forcedState(Holding.pro), HoldingState.pending);
        expect(again.serverMode, ServerModeChoice.ownServer);
        expect(again.isAnyOn, isTrue);
      });

      test('and so is a release', () async {
        await switches.apply(AccessPreset.hostedAndPro);
        await switches.setServerMode(ServerModeChoice.unknown);
        await switches.releaseAll();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().where((key) => key.startsWith('dev.')),
          isEmpty,
        );
        expect(DevAccessSwitches(prefs).isAnyOn, isFalse);
      });

      test('a toggle saved before the switches moved is force held', () async {
        final old = await _switches({
          'dev.pro_mode': true,
          'dev.pro_pack': true,
        });
        expect(old.forcedState(Holding.hosted), HoldingState.held);
        expect(old.forcedState(Holding.pro), HoldingState.held);

        // Forcing something else wins over the old key from then on.
        await old.force(Holding.hosted, HoldingState.notHeld);
        final again = DevAccessSwitches(await SharedPreferences.getInstance());
        expect(again.forcedState(Holding.hosted), HoldingState.notHeld);
        expect(again.forcedState(Holding.pro), HoldingState.held);
      });

      test('a value it does not know is no override', () async {
        final odd = await _switches({
          'dev.access.hosted': 'platinum',
          'dev.access.server': 'moon',
        });
        expect(odd.forcedState(Holding.hosted), isNull);
        expect(odd.serverMode, ServerModeChoice.real);
        expect(odd.isAnyOn, isFalse);
      });
    });

    test('a listener added through a wrapper can be removed', () async {
      final real = FakeHoldingSource(Holding.hosted);
      final wrapped = OverriddenHoldingSource(real, override: override);
      var rings = 0;
      void ring() => rings++;

      wrapped.changes.addListener(ring);
      await switches.force(Holding.hosted, HoldingState.held);
      real.ringOnly();
      expect(rings, 2);

      wrapped.changes.removeListener(ring);
      await switches.force(Holding.hosted, null);
      real.ringOnly();
      expect(rings, 2);
    });
  });
}
