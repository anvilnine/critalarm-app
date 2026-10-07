import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/features/pro_pack/data/shared_prefs_pro_pack_store.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_grant.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pro_pack_fakes.dart';

void main() {
  late FakePacksApi api;
  late MemoryProPackStore store;
  late DateTime now;
  String? accountId;

  ProPackAccess build({
    ProPackOverride? override,
    ProPackOtherGrant otherGrant = proPackGrantedElsewhere,
  }) => ProPackAccess(
    api: api,
    store: store,
    readAccountId: () async => accountId,
    override: override ?? const NoProPackOverride(),
    otherGrant: otherGrant,
    now: () => now,
  );

  setUp(() {
    api = FakePacksApi();
    store = MemoryProPackStore();
    now = DateTime.utc(2026, 10, 7, 9);
    accountId = 'acc_1';
  });

  group('each source', () {
    test('nothing from anywhere: not held', () {
      expect(build().isHeld, isFalse);
    });

    test('a registration response that lists the pack: held', () async {
      final access = build();
      await access.relayAnswered(accountId: 'acc_1', packs: const [proPack]);
      expect(access.isHeld, isTrue);
    });

    test('GET /relay/v1/packs that lists the pack: held', () async {
      api.packs = const PacksAnswer(packs: [proPack]);
      final access = build();
      await access.refresh();
      expect(access.isHeld, isTrue);
      expect(api.reads, 1);
    });

    test('the developer switch: held, and not once it is off', () {
      final devSwitch = ValueNotifier<bool>(false);
      final access = build(override: DevProPackOverride()..watch(devSwitch));
      expect(access.isHeld, isFalse);
      devSwitch.value = true;
      expect(access.isHeld, isTrue);
      devSwitch.value = false;
      expect(access.isHeld, isFalse);
    });

    test('a store build has no switch to listen to', () {
      final override = const NoProPackOverride()
        ..watch(ValueNotifier<bool>(true));
      expect(override.isForcing, isFalse);
      expect(override.listenable, isNull);
    });

    test('the mapping function, if it ever granted: held', () {
      expect(build(otherGrant: (_) => true).isHeld, isTrue);
    });

    test('the mapping function as shipped grants nothing', () {
      expect(build().isHeld, isFalse);
    });
  });

  group('never from the tier', () {
    test('a paid tier with no pack listed is not held', () async {
      for (final tier in ['relay', 'hosted', 'pro']) {
        final access = build();
        await access.relayAnswered(
          accountId: 'acc_1',
          packs: const [],
          tier: tier,
        );
        expect(access.isHeld, isFalse, reason: 'tier $tier');
      }
    });

    test('a free tier with the pack listed is held', () async {
      final access = build();
      await access.relayAnswered(
        accountId: 'acc_1',
        packs: const [proPack],
        tier: 'free',
      );
      expect(access.isHeld, isTrue);
    });

    test('the tier reaches the mapping function and nothing else', () async {
      final seen = <String?>[];
      final access = build(
        otherGrant: (sources) {
          seen.add(sources.tier);
          return false;
        },
      );
      await access.relayAnswered(
        accountId: 'acc_1',
        packs: const [],
        tier: 'hosted',
      );
      expect(access.isHeld, isFalse);
      expect(seen, contains('hosted'));
    });
  });

  group('an unknown pack id', () {
    test('is ignored on its own', () async {
      final access = build();
      await access.relayAnswered(
        accountId: 'acc_1',
        packs: const [AccountPack(id: 'team')],
      );
      expect(access.isHeld, isFalse);
    });

    test('does not hide the Pro pack beside it', () async {
      final access = build();
      await access.relayAnswered(
        accountId: 'acc_1',
        packs: const [
          AccountPack(id: 'team'),
          proPack,
        ],
      );
      expect(access.isHeld, isTrue);
    });
  });

  group('a cold start', () {
    test('with the pack kept and no network: held at once', () async {
      store.kept = const StoredPacks(accountId: 'acc_1', packs: [proPack]);
      api.packs = null;
      final access = build();
      expect(access.isHeld, isTrue);
      await access.refresh();
      expect(access.isHeld, isTrue, reason: 'a failed read changes nothing');
    });

    test('with nothing kept: not held', () {
      expect(build().isHeld, isFalse);
    });

    test('the answer goes through real preferences and back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ProPackAccess(
        api: api,
        store: SharedPrefsProPackStore(prefs),
        readAccountId: () async => 'acc_1',
        override: const NoProPackOverride(),
      );
      await first.relayAnswered(
        accountId: 'acc_1',
        packs: const [AccountPack(id: 'pro', expiresAt: 1759812345)],
      );

      final kept = SharedPrefsProPackStore(prefs).read();
      expect(kept?.accountId, 'acc_1');
      expect(kept?.packs, const [
        AccountPack(id: 'pro', expiresAt: 1759812345),
      ]);

      api.packs = null;
      final second = ProPackAccess(
        api: api,
        store: SharedPrefsProPackStore(prefs),
        readAccountId: () async => 'acc_1',
        override: const NoProPackOverride(),
      );
      expect(second.isHeld, isTrue);
    });

    test('a kept value that does not read back counts as none', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsProPackStore.key: 'not json',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(SharedPrefsProPackStore(prefs).read(), isNull);
    });

    test('the relay taking the pack away is kept too', () async {
      store.kept = const StoredPacks(accountId: 'acc_1', packs: [proPack]);
      final access = build();
      await access.refresh();
      expect(access.isHeld, isFalse);
      expect(store.kept?.packs, isEmpty);
    });

    test('a list kept for another account is dropped', () async {
      store.kept = const StoredPacks(accountId: 'acc_old', packs: [proPack]);
      api.packs = null;
      accountId = 'acc_new';
      final access = build();
      await access.refresh();
      expect(access.isHeld, isFalse);
      expect(store.kept, isNull);
    });
  });

  group('reading on launch and resume', () {
    test('a second read inside the window makes no call', () async {
      final access = build();
      await access.refresh();
      now = now.add(const Duration(seconds: 59));
      await access.refresh();
      expect(api.reads, 1);
      now = now.add(const Duration(seconds: 1));
      await access.refresh();
      expect(api.reads, 2);
    });

    test('a forced read is made anyway', () async {
      final access = build();
      await access.refresh();
      await access.refresh(force: true);
      expect(api.reads, 2);
    });

    test('two reads at once share one call', () async {
      final access = build();
      await Future.wait([access.refresh(), access.refresh(force: true)]);
      expect(api.reads, 1);
    });
  });

  group('after a purchase or a restore', () {
    PacksRefreshAnswer answer({
      required bool confirmed,
      required bool listed,
    }) => PacksRefreshAnswer(
      confirmed: confirmed,
      packs: listed ? const [proPack] : const [],
    );

    test('confirmed and listed: held and kept', () async {
      api.refreshes = [answer(confirmed: true, listed: true)];
      final access = build();
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.held);
      expect(access.isHeld, isTrue);
      expect(listsProPack(store.kept!.packs), isTrue);
    });

    test('confirmed and not listed: not held, and that is kept', () async {
      store.kept = const StoredPacks(accountId: 'acc_1', packs: [proPack]);
      api.refreshes = [answer(confirmed: true, listed: false)];
      final access = build();
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.notHeld);
      expect(access.isHeld, isFalse);
      expect(store.kept?.packs, isEmpty);
    });

    test('not confirmed and listed: held and kept', () async {
      api.refreshes = [answer(confirmed: false, listed: true)];
      final access = build();
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.held);
      expect(access.isHeld, isTrue);
    });

    test(
      'not confirmed and not listed: unknown, and what was held stays',
      () async {
        store.kept = const StoredPacks(accountId: 'acc_1', packs: [proPack]);
        api.refreshes = [answer(confirmed: false, listed: false)];
        final access = build();
        expect(await access.confirmWithStore(), ProPackRefreshOutcome.unknown);
        expect(access.isHeld, isTrue, reason: 'never read as no pack');
        expect(listsProPack(store.kept!.packs), isTrue);
        expect(store.writes, 0);
      },
    );

    test(
      'not confirmed and not listed with nothing held: still not a no',
      () async {
        api.refreshes = [answer(confirmed: false, listed: false)];
        final access = build();
        final outcome = await access.confirmWithStore();
        expect(outcome, ProPackRefreshOutcome.unknown);
        expect(outcome, isNot(ProPackRefreshOutcome.notHeld));
        expect(store.kept, isNull, reason: 'nothing was concluded or written');
      },
    );

    test('a call that fails is unknown and changes nothing', () async {
      store.kept = const StoredPacks(accountId: 'acc_1', packs: [proPack]);
      api.refreshes = [null];
      final access = build();
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.unknown);
      expect(access.isHeld, isTrue);
    });

    test('stays under the limit of 6 calls in 60 seconds', () async {
      api.refreshes = [answer(confirmed: false, listed: false)];
      final access = build();
      for (var i = 0; i < 12; i++) {
        expect(await access.confirmWithStore(), ProPackRefreshOutcome.unknown);
        now = now.add(const Duration(seconds: 1));
      }
      expect(api.refreshCalls, lessThan(ProPackAccess.refreshLimit));
      expect(api.refreshCalls, 5);

      // Once the window has passed the calls go out again.
      now = now.add(ProPackAccess.refreshWindow);
      await access.confirmWithStore();
      expect(api.refreshCalls, 6);
    });
  });

  group('a 403 pack error', () {
    test(
      'for the Pro pack reads the list again, even inside the window',
      () async {
        api.packs = const PacksAnswer(packs: [proPack]);
        final access = build();
        await access.refresh();
        expect(access.isHeld, isTrue);

        api.packs = const PacksAnswer(packs: []);
        await access.relayRefused('pro');
        expect(api.reads, 2);
        expect(access.isHeld, isFalse);
      },
    );

    test('does not take the pack away when the list still has it', () async {
      api.packs = const PacksAnswer(packs: [proPack]);
      final access = build();
      await access.refresh();
      await access.relayRefused('pro');
      expect(access.isHeld, isTrue);
    });

    test('keeps the pack when the list cannot be read', () async {
      api.packs = const PacksAnswer(packs: [proPack]);
      final access = build();
      await access.refresh();
      api.packs = null;
      await access.relayRefused('pro');
      expect(access.isHeld, isTrue);
    });

    test('for another pack does nothing', () async {
      final access = build();
      await access.relayRefused('team');
      await access.relayRefused(null);
      expect(api.reads, 0);
    });
  });

  group('the stream', () {
    test('carries changes and only changes', () async {
      final devSwitch = ValueNotifier<bool>(false);
      final access = build(override: DevProPackOverride()..watch(devSwitch));
      final seen = <bool>[];
      final sub = access.stream.listen(seen.add);

      await access.relayAnswered(accountId: 'acc_1', packs: const []);
      await access.relayAnswered(accountId: 'acc_1', packs: const [proPack]);
      await access.relayAnswered(accountId: 'acc_1', packs: const [proPack]);
      devSwitch.value = true;
      await access.relayAnswered(accountId: 'acc_1', packs: const []);
      devSwitch.value = false;
      await Future<void>.delayed(Duration.zero);

      expect(seen, [true, false]);
      await sub.cancel();
      await access.dispose();
    });
  });
}
