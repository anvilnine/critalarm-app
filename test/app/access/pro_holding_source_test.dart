import 'package:critalarm/app/access/pro_holding_source.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/pro_pack/pro_pack_fakes.dart';

const _kept = StoredPacks(accountId: 'acc_1', packs: [proPack]);
const _heldAnswer = PacksRefreshAnswer(confirmed: true, packs: [proPack]);
const _unknownAnswer = PacksRefreshAnswer(confirmed: false, packs: []);
const _readEmptyAnswer = PacksRefreshAnswer(confirmed: true, packs: []);

void main() {
  late FakePacksApi api;
  late MemoryProPackStore store;
  late DateTime now;
  late ValueNotifier<bool> devSwitch;
  String? accountId;

  Future<ProPackAccess> buildAccess() async {
    final access = ProPackAccess(
      api: api,
      store: store,
      readAccountId: () async => accountId,
      override: DevProPackOverride()..watch(devSwitch),
      now: () => now,
    );
    addTearDown(access.dispose);
    await access.ready;
    return access;
  }

  setUp(() {
    api = FakePacksApi();
    store = MemoryProPackStore();
    now = DateTime.utc(2026, 10, 8, 9);
    devSwitch = ValueNotifier(false);
    accountId = 'acc_1';
  });

  group('state', () {
    test('is pro', () async {
      expect(ProHoldingSource(await buildAccess()).holding, Holding.pro);
    });

    test('not held with nothing from anywhere', () async {
      final access = await buildAccess();
      expect(access.isStoreAcceptedAwaitingRelay, isFalse);
      expect(ProHoldingSource(access).state, HoldingState.notHeld);
    });

    test('held when the relay lists the pack', () async {
      store.kept = _kept;
      expect(ProHoldingSource(await buildAccess()).state, HoldingState.held);
    });

    test('held by the developer switch', () async {
      final source = ProHoldingSource(await buildAccess());
      devSwitch.value = true;
      expect(source.state, HoldingState.held);
    });

    test('a purchase that was only started is not held', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      expect(store.pending, isNotNull);
      expect(access.isStoreAcceptedAwaitingRelay, isFalse);
      expect(source.state, HoldingState.notHeld);
    });

    test('a started purchase left behind never becomes pending', () async {
      // The payment failed, or the app was killed at the store sheet.
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      now = now.add(const Duration(hours: 5));
      expect(source.state, HoldingState.notHeld);
    });

    test('pending once the store accepted it and the relay has not listed '
        'the pack', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      await access.purchaseAccepted();
      expect(access.isHeld, isFalse);
      expect(access.isStoreAcceptedAwaitingRelay, isTrue);
      expect(source.state, HoldingState.pending);
    });

    test('accepting keeps the time the purchase was started', () async {
      final access = await buildAccess();
      await access.purchaseStarted();
      final started = now;
      now = now.add(const Duration(minutes: 2));
      await access.purchaseAccepted();
      expect(store.pending?.since, started);
      expect(store.pending?.storeAccepted, isTrue);
    });

    test('pending while the relay still says nothing', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      await access.purchaseAccepted();
      api.refreshes = [_unknownAnswer];
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.unknown);
      expect(source.state, HoldingState.pending);
    });

    test('held once the relay lists the pack', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      await access.purchaseAccepted();
      api.refreshes = [_heldAnswer];
      await access.confirmWithStore();
      expect(source.state, HoldingState.held);
      expect(access.isStoreAcceptedAwaitingRelay, isFalse);
    });

    test('not held once the relay read the store and lists no pack', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      await access.purchaseAccepted();
      api.refreshes = [_readEmptyAnswer];
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.notHeld);
      expect(access.isStoreAcceptedAwaitingRelay, isFalse);
      expect(source.state, HoldingState.notHeld);
      // The record stays, so launch and resume keep asking as before.
      expect(store.pending, isNotNull);
      expect(store.pending?.storeAccepted, isFalse);
    });

    test('not held again when the person backed out of the store', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      await access.purchaseAccepted();
      await access.purchaseAbandoned();
      expect(store.pending, isNull);
      expect(source.state, HoldingState.notHeld);
    });

    test('an accepted purchase stops counting once the app gives up '
        'asking', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      await access.purchaseAccepted();
      now = now.add(
        ProPackAccess.pendingConfirmGivesUpAfter - const Duration(minutes: 1),
      );
      expect(source.state, HoldingState.pending);
      now = now.add(const Duration(minutes: 1));
      expect(source.state, HoldingState.notHeld);
    });

    test('an accepted purchase on another account is ignored here', () async {
      store.pending = PendingProPackConfirm(
        scope: const ProPackScope(accountId: 'acc_other', relay: ''),
        since: now,
        storeAccepted: true,
      );
      final access = await buildAccess();
      expect(access.isStoreAcceptedAwaitingRelay, isFalse);
      expect(ProHoldingSource(access).state, HoldingState.notHeld);
    });

    test('nothing is pending while the account is not known', () async {
      accountId = null;
      store.pending = PendingProPackConfirm(
        scope: const ProPackScope(accountId: 'acc_1', relay: ''),
        since: now,
        storeAccepted: true,
      );
      final access = await buildAccess();
      expect(access.isStoreAcceptedAwaitingRelay, isFalse);
    });

    test('accepting with no account known writes nothing', () async {
      accountId = null;
      final access = await buildAccess();
      await access.purchaseAccepted();
      expect(store.pending, isNull);
    });
  });

  group('changes', () {
    late ProPackAccess access;
    late ProHoldingSource source;
    var rings = 0;

    setUp(() async {
      access = await buildAccess();
      source = ProHoldingSource(access);
      rings = 0;
      source.changes.addListener(() => rings++);
    });

    test('is quiet when a purchase is only started', () async {
      await access.purchaseStarted();
      expect(rings, 0);
    });

    test('fires when the store accepts the purchase', () async {
      await access.purchaseStarted();
      await access.purchaseAccepted();
      expect(rings, 1);
      await access.purchaseAccepted();
      expect(rings, 1, reason: 'already accepted');
    });

    test('fires when an accepted purchase is dropped', () async {
      await access.purchaseStarted();
      await access.purchaseAccepted();
      await access.purchaseAbandoned();
      expect(rings, 2);
    });

    test('fires when the relay read the store and lists no pack', () async {
      await access.purchaseStarted();
      await access.purchaseAccepted();
      api.refreshes = [_readEmptyAnswer];
      await access.confirmWithStore();
      expect(rings, 2);
    });

    test('fires when the pack becomes held', () async {
      api.packs = const PacksAnswer(packs: [proPack]);
      await access.refresh(force: true);
      expect(rings, 1);
      expect(source.state, HoldingState.held);
    });

    test('fires on the developer switch', () {
      devSwitch.value = true;
      expect(rings, 1);
    });

    test('is quiet when nothing changed', () async {
      await access.refresh(force: true);
      await access.purchaseAbandoned();
      expect(rings, 0);
    });

    test('the held stream still carries only changes of isHeld', () async {
      final heard = <bool>[];
      access.stream.listen(heard.add);
      await access.purchaseStarted();
      await access.purchaseAccepted();
      await access.purchaseAbandoned();
      await settle();
      expect(heard, isEmpty);
    });
  });

  group('through Holdings to a decision', () {
    late ProPackAccess packs;
    late Holdings holdings;
    late FeatureAccess access;
    late List<AppFeature> heard;

    setUp(() async {
      packs = await buildAccess();
      holdings = Holdings([ProHoldingSource(packs)]);
      access = FeatureAccess(
        holdings: holdings,
        serverMode: ServerMode.hosted,
      );
      heard = [];
      access.changes.listen(heard.add);
      addTearDown(access.dispose);
      addTearDown(holdings.dispose);
    });

    test('the developer switch opens the Pro features', () async {
      expect(access.can(AppFeature.weeklyCheck), isFalse);
      devSwitch.value = true;
      expect(holdings.holds(Holding.pro), isTrue);
      expect(
        access.decide(AppFeature.weeklyCheck),
        const FeatureDecision.open(),
      );
      await settle();
      expect(heard, contains(AppFeature.weeklyCheck));
      expect(heard, isNot(contains(AppFeature.longHistory)));

      devSwitch.value = false;
      expect(
        access.decide(AppFeature.weeklyCheck),
        const FeatureDecision.locked(Holding.pro),
      );
    });

    test('a started purchase opens nothing', () async {
      await packs.purchaseStarted();
      for (final feature in AppFeature.values) {
        if (!featureTable[feature]!.unlockedBy.contains(Holding.pro)) continue;
        expect(
          access.decide(feature),
          const FeatureDecision.locked(Holding.pro),
          reason: feature.name,
        );
        expect(access.can(feature), isFalse, reason: feature.name);
      }
      await settle();
      expect(heard, isEmpty);
    });

    test('an accepted purchase shows as confirming, then open', () async {
      await packs.purchaseStarted();
      await packs.purchaseAccepted();
      expect(
        access.decide(AppFeature.weeklyCheck),
        const FeatureDecision.confirming(Holding.pro),
      );
      expect(access.can(AppFeature.weeklyCheck), isTrue);

      api.refreshes = [_heldAnswer];
      await packs.confirmWithStore();
      expect(
        access.decide(AppFeature.weeklyCheck),
        const FeatureDecision.open(),
      );
      await settle();
      expect(
        heard.where((feature) => feature == AppFeature.weeklyCheck),
        hasLength(2),
      );
    });
  });
}
