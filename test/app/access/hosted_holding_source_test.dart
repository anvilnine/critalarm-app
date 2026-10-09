import 'dart:async';

import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _free = DeviceIdentity(deviceId: 'd1', accountId: 'acc_1');
const _paid = DeviceIdentity(deviceId: 'd1', accountId: 'acc_1', tier: 'pro');

/// Every kind of stored identity the rule has to answer for.
const Map<String, DeviceIdentity?> _identities = {
  'no identity': null,
  'no account yet, tier free': DeviceIdentity(deviceId: 'd1'),
  'no account yet, tier paid': DeviceIdentity(deviceId: 'd1', tier: 'pro'),
  'account on free': _free,
  'account on pro': _paid,
  'account on a tier the app has no name for': DeviceIdentity(
    deviceId: 'd1',
    accountId: 'acc_1',
    tier: 'team',
  ),
};

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late PlanChanges plan;
  late AccountIdentityChanges identityChanges;
  late ValueNotifier<bool> devSwitch;
  late DevProOverride override;
  DeviceIdentity? stored;
  var reads = 0;

  Future<HostedHoldingSource> build({ProOverride? proOverride}) async {
    final source = HostedHoldingSource(
      readIdentity: () async {
        reads++;
        return stored;
      },
      planChanges: plan,
      proOverride: proOverride ?? override,
      identityChanges: [identityChanges],
    );
    addTearDown(source.dispose);
    await source.ready;
    return source;
  }

  setUp(() {
    plan = PlanChanges();
    identityChanges = AccountIdentityChanges();
    devSwitch = ValueNotifier(false);
    override = DevProOverride()..watch(devSwitch);
    stored = _free;
    reads = 0;
  });

  group('the rule', () {
    for (final entry in _identities.entries) {
      for (final storeSaysPro in [false, true]) {
        for (final isForcingPro in [false, true]) {
          test('${entry.key}, store says pro $storeSaysPro, '
              'developer switch $isForcingPro: agrees with isPaid', () {
            final casePlan = PlanChanges()
              ..setStoreSaysPro(value: storeSaysPro);
            final caseOverride = DevProOverride()
              ..watch(ValueNotifier(isForcingPro));
            final access = AccountAccess(
              entry.value,
              planChanges: casePlan,
              proOverride: caseOverride,
            );

            final state = HostedHoldingSource.stateFor(
              identity: entry.value,
              storeSaysPro: storeSaysPro,
              isForcingPro: isForcingPro,
            );

            expect(state != HoldingState.notHeld, access.isPaid);
            // Pending is the store alone: no paid tier and no switch.
            expect(
              state == HoldingState.pending,
              access.isProPending && !isForcingPro,
            );
            expect(
              state == HoldingState.held,
              access.isRegisteredPaid || isForcingPro,
            );
          });
        }
      }
    }

    test('the source itself agrees with isPaid over the same cases', () async {
      for (final entry in _identities.entries) {
        for (final storeSaysPro in [false, true]) {
          for (final isForcingPro in [false, true]) {
            stored = entry.value;
            plan.setStoreSaysPro(value: storeSaysPro);
            devSwitch.value = isForcingPro;
            final source = await build();
            final access = AccountAccess(
              entry.value,
              planChanges: plan,
              proOverride: override,
            );
            expect(
              source.state != HoldingState.notHeld,
              access.isPaid,
              reason: '${entry.key} store=$storeSaysPro dev=$isForcingPro',
            );
          }
        }
      }
    });
  });

  group('state', () {
    test('is hosted', () async {
      expect((await build()).holding, Holding.hosted);
    });

    test('not held on a free tier', () async {
      expect((await build()).state, HoldingState.notHeld);
    });

    test('held on a paid tier', () async {
      stored = _paid;
      expect((await build()).state, HoldingState.held);
    });

    test('pending when only the store says so', () async {
      final source = await build();
      plan.setStoreSaysPro(value: true);
      expect(source.state, HoldingState.pending);
    });

    test(
      'held, not pending, once the tier catches up with the store',
      () async {
        final source = await build();
        plan.setStoreSaysPro(value: true);
        stored = _paid;
        plan.bump();
        await _settle();
        expect(source.state, HoldingState.held);
      },
    );

    test('a build with no developer switch never forces it', () async {
      final source = await build(proOverride: const NoProOverride());
      expect(source.state, HoldingState.notHeld);
    });

    test('a read that fails keeps what was known', () async {
      stored = _paid;
      var isFailing = false;
      final source = HostedHoldingSource(
        readIdentity: () async {
          if (isFailing) throw Exception('keychain');
          return stored;
        },
        planChanges: plan,
        proOverride: override,
      );
      addTearDown(source.dispose);
      await source.ready;
      isFailing = true;
      plan.bump();
      await _settle();
      expect(source.state, HoldingState.held);
    });

    test('a slow read never overwrites a newer one', () async {
      final gates = <Completer<DeviceIdentity?>>[];
      final source = HostedHoldingSource(
        readIdentity: () {
          final gate = Completer<DeviceIdentity?>();
          gates.add(gate);
          return gate.future;
        },
        planChanges: plan,
        proOverride: override,
      );
      addTearDown(source.dispose);
      plan.bump();
      expect(gates, hasLength(2));
      gates[1].complete(_paid);
      await _settle();
      gates[0].complete(_free);
      await _settle();
      expect(source.state, HoldingState.held);
    });
  });

  group('changes', () {
    late HostedHoldingSource source;
    var rings = 0;

    setUp(() async {
      source = await build();
      rings = 0;
      source.changes.addListener(() => rings++);
    });

    test('fires on the store flag', () {
      plan.setStoreSaysPro(value: true);
      expect(rings, greaterThan(0));
      expect(source.state, HoldingState.pending);
    });

    test('fires on the developer switch', () {
      devSwitch.value = true;
      expect(rings, 1);
      expect(source.state, HoldingState.held);
    });

    test('reads the tier again on a plan bump and fires', () async {
      stored = _paid;
      final before = reads;
      plan.bump();
      await _settle();
      expect(reads, before + 1);
      expect(rings, greaterThan(0));
      expect(source.state, HoldingState.held);
    });

    test('reads the tier again when the identity changed', () async {
      stored = _paid;
      identityChanges.bump();
      await _settle();
      expect(source.state, HoldingState.held);
      stored = _free;
      identityChanges.bump();
      await _settle();
      expect(source.state, HoldingState.notHeld);
    });

    test('is quiet after dispose', () async {
      final own = await build();
      var heard = 0;
      own.changes.addListener(() => heard++);
      own.dispose();
      plan.setStoreSaysPro(value: true);
      devSwitch.value = true;
      identityChanges.bump();
      await _settle();
      expect(heard, 0);
    });
  });

  group('through Holdings to a decision', () {
    late Holdings holdings;
    late FeatureAccess access;
    late List<AppFeature> heard;

    setUp(() async {
      holdings = Holdings([await build()]);
      access = FeatureAccess(
        holdings: holdings,
        serverMode: ServerMode.hosted,
      );
      heard = [];
      access.changes.listen(heard.add);
      addTearDown(access.dispose);
      addTearDown(holdings.dispose);
    });

    test('the developer switch opens the Hosted features', () async {
      expect(access.can(AppFeature.longHistory), isFalse);
      devSwitch.value = true;
      expect(holdings.holds(Holding.hosted), isTrue);
      expect(
        access.decide(AppFeature.longHistory),
        const FeatureDecision.open(),
      );
      await _settle();
      expect(heard, contains(AppFeature.longHistory));
      expect(heard, isNot(contains(AppFeature.weeklyCheck)));

      devSwitch.value = false;
      expect(
        access.decide(AppFeature.longHistory),
        const FeatureDecision.locked(Holding.hosted),
      );
    });

    test('a store purchase shows as confirming until the tier lands', () async {
      plan.setStoreSaysPro(value: true);
      expect(
        access.decide(AppFeature.appIcons),
        const FeatureDecision.confirming(Holding.hosted),
      );
      expect(access.can(AppFeature.appIcons), isTrue);

      stored = _paid;
      plan.bump();
      await _settle();
      expect(access.decide(AppFeature.appIcons), const FeatureDecision.open());
    });
  });
}
