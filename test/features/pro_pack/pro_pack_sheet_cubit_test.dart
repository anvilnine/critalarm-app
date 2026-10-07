import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_store.dart';
import 'package:critalarm/features/pro_pack/presentation/cubits/pro_pack_sheet_cubit.dart';
import 'package:critalarm/features/pro_pack/presentation/cubits/pro_pack_sheet_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pro_pack_fakes.dart';

const _one = ProPackOffer(handle: 'a', title: 'Store title A', price: 'P1');
const _two = ProPackOffer(handle: 'b', title: 'Store title B', price: 'P2');

const _unknown = PacksRefreshAnswer(confirmed: false, packs: []);
const _readEmpty = PacksRefreshAnswer(confirmed: true, packs: []);
const _held = PacksRefreshAnswer(confirmed: true, packs: [proPack]);
const _heldUnread = PacksRefreshAnswer(confirmed: false, packs: [proPack]);

void main() {
  late FakePacksApi api;
  late MemoryProPackStore store;
  late FakeProPackShop shop;
  late RecordingGate gate;
  late List<Duration> waits;
  late DateTime now;

  ProPackAccess access() => ProPackAccess(
    api: api,
    store: store,
    readAccountId: () async => 'acc_1',
    override: const NoProPackOverride(),
    now: () => now,
  );

  ProPackSheetCubit build([ProPackAccess? a]) => ProPackSheetCubit(
    access: a ?? access(),
    shop: shop,
    analytics: ProPackAnalytics(gate),
    wait: (d) async {
      waits.add(d);
      now = now.add(d);
    },
  );

  setUp(() {
    api = FakePacksApi();
    store = MemoryProPackStore();
    shop = FakeProPackShop(offers: const [_one, _two]);
    gate = RecordingGate();
    waits = [];
    now = DateTime.utc(2026, 10, 7, 9);
  });

  /// No stage or note the sheet can show after a purchase says the pack is
  /// missing or the purchase failed.
  void expectNoVerdict(List<ProPackSheetState> seen) {
    for (final state in seen) {
      expect(state.note, isNull, reason: '$state');
      expect(
        state.stage,
        isIn([
          ProPackSheetStage.atStore,
          ProPackSheetStage.checking,
          ProPackSheetStage.checkingPaused,
          ProPackSheetStage.held,
        ]),
        reason: '$state',
      );
    }
  }

  group('opening', () {
    test(
      'two packages: both listed with the store strings as they come',
      () async {
        final cubit = build();
        await cubit.open(ProPackSheetSource.reliability);
        expect(cubit.state.stage, ProPackSheetStage.offers);
        expect(cubit.state.offers, const [_one, _two]);
        expect(cubit.state.offers.first.title, 'Store title A');
        expect(cubit.state.offers.first.price, 'P1');
      },
    );

    test('one package: one listed', () async {
      shop.offers = const [_one];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      expect(cubit.state.stage, ProPackSheetStage.offers);
      expect(cubit.state.offers, hasLength(1));
    });

    test('no offering: not on sale, and nothing to buy', () async {
      shop.offers = const [];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      expect(cubit.state.stage, ProPackSheetStage.notOnSale);
      await cubit.buy(_one);
      expect(shop.bought, isEmpty);
      expect(cubit.state.stage, ProPackSheetStage.notOnSale);
    });

    test('a build that skips the store: not on sale', () async {
      final cubit = ProPackSheetCubit(
        access: access(),
        shop: const ClosedProPackShop(),
      );
      await cubit.open(ProPackSheetSource.direct);
      expect(cubit.state.stage, ProPackSheetStage.notOnSale);
    });

    test('already held: says so and asks the store nothing', () async {
      store.kept = null;
      final a = access();
      await a.relayAnswered(accountId: 'acc_1', packs: const [proPack]);
      final cubit = build(a);
      await cubit.open(ProPackSheetSource.direct);
      expect(cubit.state.stage, ProPackSheetStage.held);
    });

    test('sends where it was opened from, and nothing else', () async {
      final cubit = build();
      await cubit.open(ProPackSheetSource.reliability);
      expect(gate.lines, [
        '${AnalyticsEvents.proPackSheetOpened} {source: reliability}',
      ]);
    });
  });

  group('a purchase', () {
    test('confirmed on the first ask: held', () async {
      api.refreshes = [_held];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_two);
      expect(shop.bought, ['b']);
      expect(cubit.state.stage, ProPackSheetStage.held);
      expect(api.refreshCalls, 1);
      expect(
        gate.lines.last,
        '${AnalyticsEvents.proPackPurchaseFinished} {result: held}',
      );
    });

    test('held by a list the store could not confirm: still held', () async {
      api.refreshes = [_heldUnread];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      expect(cubit.state.stage, ProPackSheetStage.held);
    });

    test(
      'confirmed false with an empty list: still checking, then tries again',
      () async {
        api.refreshes = [_unknown, _unknown, _held];
        final cubit = build();
        await cubit.open(ProPackSheetSource.direct);
        final seen = <ProPackSheetState>[];
        final sub = cubit.stream.listen(seen.add);
        await cubit.buy(_one);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(seen.map((s) => s.stage), [
          ProPackSheetStage.atStore,
          ProPackSheetStage.checking,
          ProPackSheetStage.held,
        ]);
        expectNoVerdict(seen);
        expect(api.refreshCalls, 3);
        expect(waits, const [Duration(seconds: 3), Duration(seconds: 6)]);
      },
    );

    test(
      'confirmed false every time: ends on still checking, never a failure',
      () async {
        api.refreshes = [_unknown];
        final cubit = build();
        await cubit.open(ProPackSheetSource.direct);
        final seen = <ProPackSheetState>[];
        final sub = cubit.stream.listen(seen.add);
        await cubit.buy(_one);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(cubit.state.stage, ProPackSheetStage.checkingPaused);
        expectNoVerdict(seen);
        expect(api.refreshCalls, ProPackSheetCubit.confirmWaits.length);
        expect(api.refreshCalls, lessThan(ProPackAccess.refreshLimit));
        expect(
          gate.lines.last,
          '${AnalyticsEvents.proPackPurchaseFinished} {result: checking}',
        );
      },
    );

    test('a relay that cannot be reached is still checking too', () async {
      api.refreshes = [null];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      final seen = <ProPackSheetState>[];
      final sub = cubit.stream.listen(seen.add);
      await cubit.buy(_one);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(cubit.state.stage, ProPackSheetStage.checkingPaused);
      expectNoVerdict(seen);
    });

    test(
      'a store read with nothing on it, right after buying, is not a no',
      () async {
        api.refreshes = [_readEmpty, _readEmpty, _held];
        final cubit = build();
        await cubit.open(ProPackSheetSource.direct);
        final seen = <ProPackSheetState>[];
        final sub = cubit.stream.listen(seen.add);
        await cubit.buy(_one);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(cubit.state.stage, ProPackSheetStage.held);
        expectNoVerdict(seen);
      },
    );

    test('check again asks the relay again and can end held', () async {
      api.refreshes = [_unknown];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      expect(cubit.state.stage, ProPackSheetStage.checkingPaused);

      now = now.add(ProPackAccess.refreshWindow);
      api.refreshes = [_unknown, _unknown, _unknown, _unknown, _unknown, _held];
      await cubit.checkAgain();
      expect(cubit.state.stage, ProPackSheetStage.held);
      // The second round is not reported as a second purchase.
      expect(
        gate.events.where(
          (e) => e.$1 == AnalyticsEvents.proPackPurchaseFinished,
        ),
        hasLength(1),
      );
    });

    test('backing out returns to the offers with no note', () async {
      shop.buyResult = ProPackStoreResult.cancelled;
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      expect(cubit.state.stage, ProPackSheetStage.offers);
      expect(cubit.state.note, isNull);
      expect(api.refreshCalls, 0);
      expect(gate.events, hasLength(1));
    });

    test('a problem the store itself reported shows as the store', () async {
      shop.buyResult = ProPackStoreResult.problem;
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      expect(cubit.state.stage, ProPackSheetStage.offers);
      expect(cubit.state.note, ProPackSheetNote.storeProblem);
      expect(api.refreshCalls, 0);
    });

    test('the relay answering through another door ends the wait', () async {
      api.refreshes = [_unknown];
      final a = access();
      final cubit = build(a);
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      expect(cubit.state.stage, ProPackSheetStage.checkingPaused);
      await a.relayAnswered(accountId: 'acc_1', packs: const [proPack]);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.stage, ProPackSheetStage.held);
    });
  });

  group('a payment the store is holding', () {
    setUp(() => shop.buyResult = ProPackStoreResult.pending);

    test('shows as pending, never as a store problem', () async {
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      final seen = <ProPackSheetState>[];
      final sub = cubit.stream.listen(seen.add);
      await cubit.buy(_one);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen.map((s) => s.stage), [
        ProPackSheetStage.atStore,
        ProPackSheetStage.paymentPending,
      ]);
      for (final state in seen) {
        expect(state.note, isNull, reason: '$state');
      }
      // Nothing was asked: the store has not taken the money yet.
      expect(api.refreshCalls, 0);
      // Not reported as a finished purchase.
      expect(gate.events, hasLength(1));
    });

    test('a second tap does not go back to the store', () async {
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      await cubit.buy(_one);
      await cubit.buy(_two);
      expect(shop.bought, ['a']);
      expect(cubit.state.stage, ProPackSheetStage.paymentPending);
    });

    test('the purchase stays written down', () async {
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      expect(store.pending?.scope.accountId, 'acc_1');
    });

    test('check again asks the relay, and still says pending while nobody '
        'confirms it', () async {
      api.refreshes = [_readEmpty];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);

      final seen = <ProPackSheetState>[];
      final sub = cubit.stream.listen(seen.add);
      await cubit.checkAgain();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen.map((s) => s.stage), [
        ProPackSheetStage.checking,
        ProPackSheetStage.paymentPending,
      ]);
      for (final state in seen) {
        expect(state.note, isNull, reason: '$state');
      }
      // A store read with nothing on it is not a no while a payment is held.
      expect(api.refreshCalls, ProPackSheetCubit.confirmWaits.length);
      expect(shop.bought, ['a']);
      expect(store.pending, isNotNull);
      // Check again is not reported as a purchase.
      expect(gate.events, hasLength(1));
    });

    test('check again ends held once the payment goes through', () async {
      api.refreshes = [_unknown, _held];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      await cubit.checkAgain();
      expect(cubit.state.stage, ProPackSheetStage.held);
      expect(store.pending, isNull, reason: 'the relay listed the pack');
    });

    test('the relay answering through another door ends the wait', () async {
      final a = access();
      final cubit = build(a);
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      await a.relayAnswered(accountId: 'acc_1', packs: const [proPack]);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.stage, ProPackSheetStage.held);
    });

    test('the next launch asks about it and unlocks', () async {
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      await cubit.close();

      now = now.add(const Duration(hours: 2));
      api.refreshes = [_held];
      final relaunched = access();
      await relaunched.ready;
      expect(relaunched.isHeld, isFalse);
      await relaunched.refresh();
      expect(relaunched.isHeld, isTrue);
      expect(api.refreshCalls, 1);
      expect(store.pending, isNull);
    });

    test('a restore from there is a restore, with its own ending', () async {
      api.refreshes = [_readEmpty];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      await cubit.restore();
      expect(shop.restores, 1);
      expect(cubit.state.stage, ProPackSheetStage.offers);
      expect(cubit.state.note, ProPackSheetNote.nothingToRestore);
    });

    test('a purchase after a held one pauses on its own line again', () async {
      api.refreshes = [_readEmpty];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      await cubit.restore();

      now = now.add(ProPackAccess.refreshWindow);
      shop.buyResult = ProPackStoreResult.done;
      api
        ..refreshCalls = 0
        ..refreshes = [_unknown];
      await cubit.buy(_one);
      expect(cubit.state.stage, ProPackSheetStage.checkingPaused);
    });
  });

  group('a restore', () {
    test('finds the pack: held', () async {
      api.refreshes = [_held];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.restore();
      expect(shop.restores, 1);
      expect(cubit.state.stage, ProPackSheetStage.held);
      expect(
        gate.lines.last,
        '${AnalyticsEvents.proPackRestoreFinished} {result: held}',
      );
    });

    test(
      'the store was read and holds nothing: says nothing to restore',
      () async {
        api.refreshes = [_readEmpty];
        final cubit = build();
        await cubit.open(ProPackSheetSource.direct);
        await cubit.restore();
        expect(cubit.state.stage, ProPackSheetStage.offers);
        expect(cubit.state.note, ProPackSheetNote.nothingToRestore);
        expect(api.refreshCalls, 1);
        expect(
          gate.lines.last,
          '${AnalyticsEvents.proPackRestoreFinished} {result: none}',
        );
      },
    );

    test(
      'confirmed false with an empty list: still checking, not nothing',
      () async {
        api.refreshes = [_unknown];
        final cubit = build();
        await cubit.open(ProPackSheetSource.direct);
        await cubit.restore();
        expect(cubit.state.stage, ProPackSheetStage.checkingPaused);
        expect(cubit.state.note, isNull);
        expect(
          gate.lines.last,
          '${AnalyticsEvents.proPackRestoreFinished} {result: checking}',
        );
      },
    );

    test('a store problem shows as the store', () async {
      shop.restoreResult = ProPackStoreResult.problem;
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.restore();
      expect(cubit.state.note, ProPackSheetNote.storeProblem);
    });
  });

  group('restore with nothing on sale', () {
    setUp(() => shop.offers = const []);

    test('a buyer on a second phone restores and holds the pack', () async {
      api.refreshes = [_held];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      expect(cubit.state.stage, ProPackSheetStage.notOnSale);
      expect(ProPackSheetCubit.canRestore(cubit.state.stage), isTrue);
      await cubit.restore();
      expect(shop.restores, 1);
      expect(cubit.state.stage, ProPackSheetStage.held);
    });

    test('nothing found goes back to not on sale, with the note', () async {
      api.refreshes = [_readEmpty];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.restore();
      expect(cubit.state.stage, ProPackSheetStage.notOnSale);
      expect(cubit.state.note, ProPackSheetNote.nothingToRestore);
    });

    test('a store problem goes back to not on sale, with the note', () async {
      shop.restoreResult = ProPackStoreResult.problem;
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.restore();
      expect(cubit.state.stage, ProPackSheetStage.notOnSale);
      expect(cubit.state.note, ProPackSheetNote.storeProblem);
    });

    test('the relay saying nothing is still checking', () async {
      api.refreshes = [_unknown];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.restore();
      expect(cubit.state.stage, ProPackSheetStage.checkingPaused);
    });
  });

  group('where Restore is', () {
    test('every resting state, and never while something runs', () {
      expect(
        {
          for (final stage in ProPackSheetStage.values)
            stage: ProPackSheetCubit.canRestore(stage),
        },
        {
          ProPackSheetStage.loading: false,
          ProPackSheetStage.notOnSale: true,
          ProPackSheetStage.offers: true,
          ProPackSheetStage.atStore: false,
          ProPackSheetStage.checking: false,
          ProPackSheetStage.checkingPaused: true,
          ProPackSheetStage.paymentPending: true,
          ProPackSheetStage.held: false,
        },
      );
    });

    test('from still checking, a restore can end held', () async {
      api.refreshes = [_unknown];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      expect(cubit.state.stage, ProPackSheetStage.checkingPaused);

      now = now.add(ProPackAccess.refreshWindow);
      api.refreshes = [_unknown, _unknown, _unknown, _unknown, _unknown, _held];
      await cubit.restore();
      expect(shop.restores, 1);
      expect(cubit.state.stage, ProPackSheetStage.held);
    });

    test('a second tap while the store is busy does nothing', () async {
      api.refreshes = [_held];
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      final first = cubit.restore();
      await cubit.restore();
      await first;
      expect(shop.restores, 1);
    });
  });

  group('a purchase the app may not live to see confirmed', () {
    test('it is written down before the store is asked', () async {
      api.refreshes = [_held];
      PendingProPackConfirm? atStore;
      shop.onBuy = () => atStore = store.pending;
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      expect(atStore?.scope.accountId, 'acc_1');
      expect(store.pending, isNull, reason: 'the relay listed the pack');
    });

    test('backing out forgets it', () async {
      shop.buyResult = ProPackStoreResult.cancelled;
      final cubit = build();
      await cubit.open(ProPackSheetSource.direct);
      await cubit.buy(_one);
      expect(store.pending, isNull);
    });

    test(
      'killed while still checking: the next launch asks and unlocks',
      () async {
        api.refreshes = [_unknown];
        final cubit = build();
        await cubit.open(ProPackSheetSource.direct);
        await cubit.buy(_one);
        expect(cubit.state.stage, ProPackSheetStage.checkingPaused);
        expect(store.pending, isNotNull);
        await cubit.close();

        // The app starts again. Launch reads the list and, because a
        // purchase is waiting, asks the relay to read the store.
        now = now.add(const Duration(hours: 2));
        api
          ..refreshCalls = 0
          ..refreshes = [_held];
        final relaunched = access();
        await relaunched.ready;
        expect(relaunched.isHeld, isFalse);
        await relaunched.refresh();
        expect(relaunched.isHeld, isTrue);
        expect(api.refreshCalls, 1);
        expect(store.pending, isNull);
      },
    );
  });

  test('no event carries more than a source or a result word', () async {
    api.refreshes = [_readEmpty, _held];
    final cubit = build();
    await cubit.open(ProPackSheetSource.reliability);
    await cubit.restore();
    await cubit.buy(_two);
    expect(gate.events, hasLength(3));
    for (final (_, params) in gate.events) {
      expect(params!.keys.single, isIn(['source', 'result']));
      expect(
        params.values.single,
        isIn(['reliability', 'direct', 'held', 'none', 'checking']),
      );
    }
  });
}
