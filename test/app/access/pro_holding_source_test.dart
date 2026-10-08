import 'package:critalarm/app/access/pro_holding_source.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/pro_pack/pro_pack_fakes.dart';

const _kept = StoredPacks(accountId: 'acc_1', packs: [proPack]);
const _heldAnswer = PacksRefreshAnswer(confirmed: true, packs: [proPack]);

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
      expect(access.isPurchaseWaiting, isFalse);
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

    test('pending while a purchase waits for the relay', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      expect(access.isHeld, isFalse);
      expect(access.isPurchaseWaiting, isTrue);
      expect(source.state, HoldingState.pending);
    });

    test('not held again when the person backed out of the store', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      await access.purchaseAbandoned();
      expect(source.state, HoldingState.notHeld);
    });

    test('held once the relay confirms the purchase', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      api.refreshes = [_heldAnswer];
      await access.confirmWithStore();
      expect(source.state, HoldingState.held);
      expect(access.isPurchaseWaiting, isFalse);
    });

    test('a purchase stops waiting once the app gives up asking', () async {
      final access = await buildAccess();
      final source = ProHoldingSource(access);
      await access.purchaseStarted();
      now = now.add(
        ProPackAccess.pendingConfirmGivesUpAfter - const Duration(minutes: 1),
      );
      expect(source.state, HoldingState.pending);
      now = now.add(const Duration(minutes: 1));
      expect(source.state, HoldingState.notHeld);
    });

    test('a purchase waiting on another account is not pending here', () async {
      store.pending = PendingProPackConfirm(
        scope: const ProPackScope(accountId: 'acc_other', relay: ''),
        since: now,
      );
      final access = await buildAccess();
      expect(access.isPurchaseWaiting, isFalse);
      expect(ProHoldingSource(access).state, HoldingState.notHeld);
    });

    test('nothing is pending while the account is not known', () async {
      accountId = null;
      store.pending = PendingProPackConfirm(
        scope: const ProPackScope(accountId: 'acc_1', relay: ''),
        since: now,
      );
      final access = await buildAccess();
      expect(access.isPurchaseWaiting, isFalse);
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

    test('fires when a purchase starts waiting', () async {
      await access.purchaseStarted();
      expect(rings, 1);
    });

    test('fires when a waiting purchase is dropped', () async {
      await access.purchaseStarted();
      await access.purchaseAbandoned();
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
      expect(access.can(AppFeature.widgets), isFalse);
      devSwitch.value = true;
      expect(holdings.holds(Holding.pro), isTrue);
      expect(access.decide(AppFeature.widgets), const FeatureDecision.open());
      await settle();
      expect(heard, contains(AppFeature.widgets));
      expect(heard, isNot(contains(AppFeature.longHistory)));

      devSwitch.value = false;
      expect(
        access.decide(AppFeature.widgets),
        const FeatureDecision.locked(Holding.pro),
      );
    });

    test('a waiting purchase shows as confirming, then open', () async {
      await packs.purchaseStarted();
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
