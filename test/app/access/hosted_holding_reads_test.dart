import 'dart:async';

import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/paywall/data/repositories/in_memory_subscription_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _free = DeviceIdentity(deviceId: 'd1', accountId: 'acc_1');
const _paid = DeviceIdentity(deviceId: 'd1', accountId: 'acc_1', tier: 'pro');

void main() {
  group('ready', () {
    test('follows the read that a change started', () async {
      final plan = PlanChanges();
      var stored = _free;
      Completer<void>? gate;
      final source = HostedHoldingSource(
        readIdentity: () async {
          await gate?.future;
          return stored;
        },
        planChanges: plan,
        proOverride: const NoProOverride(),
      );
      addTearDown(source.dispose);
      await source.ready;
      expect(source.state, HoldingState.notHeld);

      // A registration saved a paid tier and bumped the plan. The read it
      // started is still out.
      stored = _paid;
      gate = Completer();
      plan.bump();
      var isReady = false;
      unawaited(source.ready.then((_) => isReady = true));
      await pumpEventQueue();
      expect(isReady, isFalse);
      expect(source.state, HoldingState.notHeld);

      gate.complete();
      await pumpEventQueue();
      expect(isReady, isTrue);
      expect(source.state, HoldingState.held);
    });
  });

  group('ready, with a second change while it waits', () {
    test('waits for the newer read as well', () async {
      final plan = PlanChanges();
      var stored = _free;
      final gates = <Completer<void>>[];
      var isGated = false;
      final source = HostedHoldingSource(
        readIdentity: () async {
          if (isGated) {
            final gate = Completer<void>();
            gates.add(gate);
            await gate.future;
          }
          return stored;
        },
        planChanges: plan,
        proOverride: const NoProOverride(),
      );
      addTearDown(source.dispose);
      await source.ready;

      isGated = true;
      plan.bump();
      var isReady = false;
      unawaited(source.ready.then((_) => isReady = true));
      // A registration lands while the first read is out, and bumps again.
      stored = _paid;
      plan.bump();
      await pumpEventQueue();
      expect(gates, hasLength(2));

      // The older read comes back and is thrown away.
      gates.first.complete();
      await pumpEventQueue();
      expect(isReady, isFalse);

      gates.last.complete();
      await pumpEventQueue();
      expect(isReady, isTrue);
      expect(source.state, HoldingState.held);
    });
  });

  group('the stored identity', () {
    late DeviceIdentityStore identity;
    late HostedHoldingSource source;

    Future<void> register(String tier) => identity.saveRegistration(
      deviceToken: 'dv_1',
      accountId: 'acc_1',
      tier: tier,
      caps: tier == 'free' ? AccountCaps.free : const AccountCaps(),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({'device_id': 'dev_1'});
      identity = DeviceIdentityStore(await SharedPreferences.getInstance());
      await register('hosted');
      source = HostedHoldingSource(
        readIdentity: identity.readOrCreate,
        planChanges: PlanChanges(),
        proOverride: const NoProOverride(),
        identityChanges: [identity.changes],
      );
      addTearDown(source.dispose);
      await source.ready;
    });

    test('a saved registration is read again with nobody bumping', () async {
      expect(source.state, HoldingState.held);
      await register('free');
      await source.ready;
      expect(source.state, HoldingState.notHeld);

      await register('hosted');
      await source.ready;
      expect(source.state, HoldingState.held);
    });

    test('a reset identity no longer holds the old tier', () async {
      await identity.resetIdentity();
      await source.ready;
      expect(source.state, HoldingState.notHeld);
    });

    test('a cleared identity no longer holds the old tier', () async {
      await identity.clear();
      await source.ready;
      expect(source.state, HoldingState.notHeld);
    });
  });

  group('readHeldByServer', () {
    test('is the registered tier, read at that moment', () async {
      var stored = _free;
      final source = HostedHoldingSource(
        readIdentity: () async => stored,
        planChanges: PlanChanges(),
        proOverride: const NoProOverride(),
      );
      addTearDown(source.dispose);
      await source.ready;
      expect(await source.readHeldByServer(), isFalse);

      // No change is announced. The read is fresh anyway.
      stored = _paid;
      expect(await source.readHeldByServer(), isTrue);
    });

    test('ignores the developer switch and the store', () async {
      final devSwitch = ValueNotifier(true);
      final plan = PlanChanges()..setStoreSaysPro(value: true);
      final source = HostedHoldingSource(
        readIdentity: () async => _free,
        planChanges: plan,
        proOverride: DevProOverride()..watch(devSwitch),
      );
      addTearDown(source.dispose);
      await source.ready;
      expect(source.state, HoldingState.held);
      expect(await source.readHeldByServer(), isFalse);
    });
  });

  group('storeMayStillHold', () {
    HostedHoldingSource build(InMemorySubscriptionRepository? store) {
      final source = HostedHoldingSource(
        readIdentity: () async => _free,
        planChanges: PlanChanges(),
        proOverride: const NoProOverride(),
        readStore: store == null ? null : () => store,
      );
      addTearDown(source.dispose);
      return source;
    }

    test('is what the store says', () async {
      final store = InMemorySubscriptionRepository();
      final source = build(store);
      expect(await source.storeMayStillHold(), isFalse);
      store.isPro = true;
      expect(await source.storeMayStillHold(), isTrue);
    });

    test('is false in a build with no store', () async {
      expect(await build(null).storeMayStillHold(), isFalse);
    });
  });
}
