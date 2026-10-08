import 'package:critalarm/core/api/packs_api.dart';
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

class _Bumps extends ChangeNotifier {
  void bump() => notifyListeners();
}

final Uri _relayOne = Uri.parse('https://relay.one');
final Uri _relayTwo = Uri.parse('https://relay.two');

const _keptForOne = StoredPacks(accountId: 'acc_1', packs: [proPack]);
const _heldAnswer = PacksRefreshAnswer(confirmed: true, packs: [proPack]);
const _unknownAnswer = PacksRefreshAnswer(confirmed: false, packs: []);

int _seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

void main() {
  late FakePacksApi api;
  late MemoryProPackStore store;
  late DateTime now;
  late _Bumps identity;
  String? accountId;
  Uri? relay;

  /// [onRelay] makes the relay part of who the phone is, as the app does.
  Future<ProPackAccess> build({
    PacksApi? relayApi,
    ProPackOverride? override,
    ProPackOtherGrant otherGrant = proPackGrantedElsewhere,
    bool onRelay = false,
  }) async {
    final access = ProPackAccess(
      api: relayApi ?? api,
      store: store,
      readAccountId: () async => accountId,
      readRelay: onRelay ? () async => relay : null,
      identityChanges: [identity],
      override: override ?? const NoProPackOverride(),
      otherGrant: otherGrant,
      now: () => now,
    );
    await access.ready;
    return access;
  }

  setUp(() {
    api = FakePacksApi();
    store = MemoryProPackStore();
    now = DateTime.utc(2026, 10, 7, 9);
    identity = _Bumps();
    accountId = 'acc_1';
    relay = _relayOne;
  });

  group('each source', () {
    test('nothing from anywhere: not held', () async {
      expect((await build()).isHeld, isFalse);
    });

    test('a registration response that lists the pack: held', () async {
      final access = await build();
      await access.relayAnswered(accountId: 'acc_1', packs: const [proPack]);
      expect(access.isHeld, isTrue);
    });

    test('GET /relay/v1/packs that lists the pack: held', () async {
      api.packs = const PacksAnswer(packs: [proPack]);
      final access = await build();
      await access.refresh();
      expect(access.isHeld, isTrue);
      expect(api.reads, 1);
    });

    test('the developer switch: held, and not once it is off', () async {
      final devSwitch = ValueNotifier<bool>(false);
      final access = await build(
        override: DevProPackOverride()..watch(devSwitch),
      );
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

    test('the mapping function, if it ever granted: held', () async {
      expect((await build(otherGrant: (_) => true)).isHeld, isTrue);
    });

    test('the mapping function as shipped grants nothing', () async {
      expect((await build()).isHeld, isFalse);
    });
  });

  group('never from the tier', () {
    test('a paid tier with no pack listed is not held', () async {
      for (final tier in ['relay', 'hosted', 'pro']) {
        final access = await build();
        await access.relayAnswered(
          accountId: 'acc_1',
          packs: const [],
          tier: tier,
        );
        expect(access.isHeld, isFalse, reason: 'tier $tier');
      }
    });

    test('a free tier with the pack listed is held', () async {
      final access = await build();
      await access.relayAnswered(
        accountId: 'acc_1',
        packs: const [proPack],
        tier: 'free',
      );
      expect(access.isHeld, isTrue);
    });

    test('the tier reaches the mapping function and nothing else', () async {
      final seen = <String?>[];
      final access = await build(
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
      final access = await build();
      await access.relayAnswered(
        accountId: 'acc_1',
        packs: const [AccountPack(id: 'team')],
      );
      expect(access.isHeld, isFalse);
    });

    test('does not hide the Pro pack beside it', () async {
      final access = await build();
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
    test(
      'with the pack kept and no network: held once the account is read',
      () async {
        store.kept = _keptForOne;
        api.packs = null;
        final access = ProPackAccess(
          api: api,
          store: store,
          readAccountId: () async => accountId,
          override: const NoProPackOverride(),
          now: () => now,
        );
        expect(access.isHeld, isFalse, reason: 'the account is not read yet');
        await access.ready;
        expect(access.isHeld, isTrue);
        await access.refresh();
        expect(access.isHeld, isTrue, reason: 'a failed read changes nothing');
      },
    );

    test('the stream says so when the kept pack comes in', () async {
      store.kept = _keptForOne;
      final access = ProPackAccess(
        api: api,
        store: store,
        readAccountId: () async => accountId,
        override: const NoProPackOverride(),
      );
      expect(await access.stream.first, isTrue);
    });

    test('with nothing kept: not held', () async {
      expect((await build()).isHeld, isFalse);
    });

    test('the answer goes through real preferences and back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = MemoryProPackStore();
      final first = ProPackAccess(
        api: api,
        store: SharedPrefsProPackStore(prefs),
        readAccountId: () async => 'acc_1',
        readRelay: () async => _relayOne,
        override: const NoProPackOverride(),
        now: () => now,
      );
      await first.relayAnswered(
        accountId: 'acc_1',
        packs: const [AccountPack(id: 'pro', expiresAt: 1999999999)],
      );
      await first.purchaseStarted();

      final kept = SharedPrefsProPackStore(prefs).read();
      expect(kept?.accountId, 'acc_1');
      expect(kept?.relay, 'https://relay.one');
      expect(kept?.answeredAt?.isAtSameMomentAs(now), isTrue);
      expect(kept?.packs, const [
        AccountPack(id: 'pro', expiresAt: 1999999999),
      ]);
      final pending = SharedPrefsProPackStore(prefs).readPending();
      expect(
        pending?.scope,
        const ProPackScope(accountId: 'acc_1', relay: 'https://relay.one'),
      );
      expect(pending?.since.isAtSameMomentAs(now), isTrue);

      api.packs = null;
      final second = ProPackAccess(
        api: api,
        store: SharedPrefsProPackStore(prefs),
        readAccountId: () async => 'acc_1',
        readRelay: () async => _relayOne,
        override: const NoProPackOverride(),
        now: () => now,
      );
      await second.ready;
      expect(second.isHeld, isTrue);
    });

    test('the accepted mark is kept, and a record without it reads as only '
        'started', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final kept = SharedPrefsProPackStore(prefs);
      const scope = ProPackScope(accountId: 'acc_1', relay: '');

      await kept.writePending(PendingProPackConfirm(scope: scope, since: now));
      expect(kept.readPending()?.storeAccepted, isFalse);
      expect(
        prefs.getString(SharedPrefsProPackStore.pendingKey),
        isNot(contains('store_accepted')),
      );

      await kept.writePending(
        PendingProPackConfirm(scope: scope, since: now, storeAccepted: true),
      );
      final read = kept.readPending();
      expect(read?.storeAccepted, isTrue);
      expect(read?.scope, scope);
      expect(read?.since.isAtSameMomentAs(now), isTrue);

      // Only a written true counts.
      await prefs.setString(
        SharedPrefsProPackStore.pendingKey,
        '{"account_id":"acc_1","relay":"","since":1,"store_accepted":"yes"}',
      );
      expect(kept.readPending()?.storeAccepted, isFalse);
    });

    test('a kept value that does not read back counts as none', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsProPackStore.key: 'not json',
        SharedPrefsProPackStore.pendingKey: '{"account_id":3}',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(SharedPrefsProPackStore(prefs).read(), isNull);
      expect(SharedPrefsProPackStore(prefs).readPending(), isNull);
    });

    test('the relay taking the pack away is kept too', () async {
      store.kept = _keptForOne;
      final access = await build();
      await access.refresh();
      expect(access.isHeld, isFalse);
      expect(store.kept?.packs, isEmpty);
    });
  });

  group('one account, one relay', () {
    test(
      'the next account is not known yet: the last pack is not shown',
      () async {
        // Account A held the pack. The phone signed out, and the
        // registration that would name account B has not come back.
        store.kept = _keptForOne;
        accountId = null;
        api.packs = null;
        final access = await build();
        expect(access.isHeld, isFalse);
        await access.refresh();
        expect(access.isHeld, isFalse);
        expect(api.reads, 0, reason: 'nobody to ask about');
      },
    );

    test(
      'another account is known: not held, and the list is dropped',
      () async {
        store.kept = _keptForOne;
        accountId = 'acc_2';
        api.packs = null;
        final access = await build();
        expect(access.isHeld, isFalse);
        expect(store.kept, isNull);
      },
    );

    test('the account changes while the app runs', () async {
      store.kept = _keptForOne;
      final access = await build();
      expect(access.isHeld, isTrue);
      final seen = <bool>[];
      final sub = access.stream.listen(seen.add);

      // Signed out: no account until the next registration answers.
      accountId = null;
      identity.bump();
      await settle();
      expect(access.isHeld, isFalse);
      expect(store.kept, isNotNull, reason: 'nothing says who is next yet');

      // The registration for account B fails, then B is known.
      accountId = 'acc_2';
      identity.bump();
      await settle();
      expect(access.isHeld, isFalse);
      expect(store.kept, isNull);
      expect(seen, [false]);
      await sub.cancel();
    });

    test('the same account coming back shows its pack again', () async {
      store.kept = _keptForOne;
      final access = await build();
      accountId = null;
      identity.bump();
      await settle();
      expect(access.isHeld, isFalse);
      accountId = 'acc_1';
      identity.bump();
      await settle();
      expect(access.isHeld, isTrue);
    });

    test("a registration for account B replaces account A's list", () async {
      store.kept = _keptForOne;
      final access = await build();
      accountId = 'acc_2';
      await access.relayAnswered(accountId: 'acc_2', packs: const []);
      expect(access.isHeld, isFalse);
      expect(store.kept?.accountId, 'acc_2');
    });

    test('a connect to a different server: not held, list dropped', () async {
      store.kept = const StoredPacks(
        accountId: 'acc_1',
        relay: 'https://relay.one',
        packs: [proPack],
      );
      final access = await build(onRelay: true);
      expect(access.isHeld, isTrue);

      // The same account id on another relay is another account.
      relay = _relayTwo;
      identity.bump();
      await settle();
      expect(access.isHeld, isFalse);
      expect(store.kept, isNull);
    });

    test('a different server is also caught by the next read', () async {
      store.kept = const StoredPacks(
        accountId: 'acc_1',
        relay: 'https://relay.one',
        packs: [proPack],
      );
      api.packs = null;
      final access = await build(onRelay: true);
      relay = _relayTwo;
      await access.refresh();
      expect(access.isHeld, isFalse);
      expect(store.kept, isNull);
    });

    test('no server connected: nothing is held from the relay', () async {
      store.kept = const StoredPacks(
        accountId: 'acc_1',
        relay: 'https://relay.one',
        packs: [proPack],
      );
      relay = null;
      final access = await build(onRelay: true);
      expect(access.isHeld, isFalse);
      expect(store.kept, isNotNull);
    });

    test(
      'a connect registers before it saves its session: the answer stands',
      () async {
        final access = await build(onRelay: true);
        // The registration went to relay two. The saved session still
        // names relay one for a moment.
        accountId = 'acc_2';
        await access.relayAnswered(
          accountId: 'acc_2',
          packs: const [proPack],
          relay: _relayTwo,
        );
        expect(access.isHeld, isTrue);
        expect(store.kept?.relay, 'https://relay.two');

        api.packs = const PacksAnswer(packs: [proPack]);
        await access.refresh();
        expect(access.isHeld, isTrue, reason: 'the session has not moved');

        relay = _relayTwo;
        identity.bump();
        await settle();
        expect(access.isHeld, isTrue, reason: 'the session caught up');

        relay = Uri.parse('https://relay.three');
        identity.bump();
        await settle();
        expect(access.isHeld, isFalse, reason: 'now it is another server');
      },
    );

    test(
      'an answer asked for account A is dropped once the phone is B',
      () async {
        final gated = GatedPacksApi();
        final access = await build(relayApi: gated);
        final reading = access.refresh();
        await settle();
        expect(gated.reads, hasLength(1));

        accountId = 'acc_2';
        identity.bump();
        await settle();
        gated.reads.single.complete(const PacksAnswer(packs: [proPack]));
        await reading;
        expect(access.isHeld, isFalse);
        expect(store.kept, isNull);
      },
    );

    test('a refresh asked for account A is not a yes for account B', () async {
      final gated = GatedPacksApi();
      final access = await build(relayApi: gated);
      final confirming = access.confirmWithStore();
      await settle();
      accountId = 'acc_2';
      identity.bump();
      await settle();
      gated.refreshes.single.complete(_heldAnswer);
      expect(await confirming, ProPackRefreshOutcome.unknown);
      expect(access.isHeld, isFalse);
    });

    test('a slow look at the identity does not undo a registration', () async {
      // The plan-change bump fires inside a registration, before its packs
      // are handed over. The look it starts must not win over the answer.
      store.kept = _keptForOne;
      final access = await build();
      identity.bump();
      accountId = 'acc_2';
      await access.relayAnswered(accountId: 'acc_2', packs: const [proPack]);
      await settle();
      expect(access.isHeld, isTrue);
      expect(store.kept?.accountId, 'acc_2');
    });
  });

  group('one writer', () {
    test(
      'a launch read that returns after a purchase refresh does not undo it',
      () async {
        final gated = GatedPacksApi();
        final access = await build(relayApi: gated);

        // Launch asks for the list. Then the buyer pays.
        final reading = access.refresh();
        await settle();
        final confirming = access.confirmWithStore();
        await settle();
        expect(gated.reads, hasLength(1));
        expect(
          gated.refreshes,
          isEmpty,
          reason: 'the refresh waits its turn behind the read',
        );

        // The read comes back with the list from before the purchase.
        gated.reads.single.complete(const PacksAnswer(packs: []));
        await reading;
        expect(access.isHeld, isFalse);
        await settle();
        gated.refreshes.single.complete(_heldAnswer);
        expect(await confirming, ProPackRefreshOutcome.held);
        expect(access.isHeld, isTrue);
        expect(listsProPack(store.kept!.packs), isTrue);
      },
    );

    test('the other order: the refresh first, then a read', () async {
      final gated = GatedPacksApi();
      final access = await build(relayApi: gated);

      final confirming = access.confirmWithStore();
      await settle();
      final reading = access.refresh();
      await settle();
      expect(gated.refreshes, hasLength(1));
      expect(gated.reads, isEmpty, reason: 'the read waits its turn');

      gated.refreshes.single.complete(_heldAnswer);
      expect(await confirming, ProPackRefreshOutcome.held);
      expect(access.isHeld, isTrue);
      await settle();
      // The read was sent after the relay had the pack, so it lists it.
      gated.reads.single.complete(const PacksAnswer(packs: [proPack]));
      await reading;
      expect(access.isHeld, isTrue);
    });

    test(
      'a registration that started before a refresh and answers after it',
      () async {
        api.refreshes = [_heldAnswer];
        final access = await build();
        final request = access.beginRelayRequest();
        expect(await access.confirmWithStore(), ProPackRefreshOutcome.held);

        // The registration left before the purchase and comes back late.
        await access.relayAnswered(
          accountId: 'acc_1',
          packs: const [],
          request: request,
        );
        expect(access.isHeld, isTrue);
        expect(listsProPack(store.kept!.packs), isTrue);
      },
    );

    test(
      'a registration that starts and answers while a refresh is out',
      () async {
        final gated = GatedPacksApi();
        final access = await build(relayApi: gated);
        final confirming = access.confirmWithStore();
        await settle();

        final request = access.beginRelayRequest();
        await access.relayAnswered(
          accountId: 'acc_1',
          packs: const [],
          request: request,
        );
        expect(access.isHeld, isFalse);

        // The refresh read the store inside the call, so it is the newer.
        gated.refreshes.single.complete(_heldAnswer);
        expect(await confirming, ProPackRefreshOutcome.held);
        expect(access.isHeld, isTrue);
      },
    );

    test(
      'a read that started before a registration and answers after',
      () async {
        final gated = GatedPacksApi();
        final access = await build(relayApi: gated);
        final reading = access.refresh();
        await settle();

        await access.relayAnswered(
          accountId: 'acc_1',
          packs: const [proPack],
          request: access.beginRelayRequest(),
        );
        gated.reads.single.complete(const PacksAnswer(packs: []));
        await reading;
        expect(access.isHeld, isTrue, reason: 'the older answer was dropped');
      },
    );

    test('registrations in order each apply', () async {
      final access = await build();
      await access.relayAnswered(
        accountId: 'acc_1',
        packs: const [proPack],
        request: access.beginRelayRequest(),
      );
      await access.relayAnswered(
        accountId: 'acc_1',
        packs: const [],
        request: access.beginRelayRequest(),
      );
      expect(access.isHeld, isFalse);
    });
  });

  group('a purchase the relay has not confirmed', () {
    test(
      'the app is killed after the store finished: the next launch confirms',
      () async {
        final first = await build();
        await first.purchaseStarted();
        expect(store.pending?.scope.accountId, 'acc_1');

        // A new run of the app. Launch reads the list, which is still
        // empty, and then asks the relay to read the store.
        api
          ..packs = const PacksAnswer(packs: [])
          ..refreshes = [_heldAnswer];
        final second = await build();
        expect(second.isHeld, isFalse);
        await second.refresh();
        expect(api.reads, 1);
        expect(api.refreshCalls, 1);
        expect(second.isHeld, isTrue);
        expect(store.pending, isNull);
      },
    );

    test('still unknown: it stays pending and resume asks again', () async {
      await (await build()).purchaseStarted();
      api.refreshes = [_unknownAnswer, _unknownAnswer, _heldAnswer];
      final access = await build();

      await access.refresh();
      expect(access.isHeld, isFalse);
      expect(store.pending, isNotNull);
      expect(api.refreshCalls, 1);

      // A resume inside the window asks nothing.
      now = now.add(const Duration(seconds: 30));
      await access.refresh();
      expect(api.refreshCalls, 1);

      now = now.add(const Duration(seconds: 30));
      await access.refresh();
      expect(api.refreshCalls, 2);
      expect(store.pending, isNotNull);

      now = now.add(const Duration(minutes: 5));
      await access.refresh();
      expect(access.isHeld, isTrue);
      expect(store.pending, isNull);
    });

    test('the store read with nothing on it does not end the asking', () async {
      await (await build()).purchaseStarted();
      api.refreshes = [const PacksRefreshAnswer(confirmed: true, packs: [])];
      final access = await build();
      await access.refresh();
      expect(store.pending, isNotNull);
    });

    test('the list already has the pack: no refresh is spent', () async {
      await (await build()).purchaseStarted();
      api.packs = const PacksAnswer(packs: [proPack]);
      final access = await build();
      await access.refresh();
      expect(access.isHeld, isTrue);
      expect(api.refreshCalls, 0);
      expect(store.pending, isNull);
    });

    test('it gives up after the bound', () async {
      await (await build()).purchaseStarted();
      api.refreshes = [_unknownAnswer];
      now = now
          .add(ProPackAccess.pendingConfirmGivesUpAfter)
          .subtract(const Duration(minutes: 1));
      final access = await build();
      await access.refresh();
      expect(api.refreshCalls, 1, reason: 'one minute inside the bound');

      now = now.add(const Duration(minutes: 2));
      await access.refresh();
      expect(api.refreshCalls, 1, reason: 'past the bound');
      expect(store.pending, isNull);
    });

    test('backing out of the store forgets it', () async {
      final access = await build();
      await access.purchaseStarted();
      await access.purchaseAbandoned();
      expect(store.pending, isNull);
      await access.refresh();
      expect(api.refreshCalls, 0);
    });

    test('it is never asked about for another account', () async {
      await (await build()).purchaseStarted();
      accountId = 'acc_2';
      api.refreshes = [_heldAnswer];
      final access = await build();
      expect(store.pending, isNull);
      await access.refresh();
      expect(api.refreshCalls, 0);
      expect(access.isHeld, isFalse);
    });

    test('with no account known nothing is written down', () async {
      accountId = null;
      await (await build()).purchaseStarted();
      expect(store.pending, isNull);
    });

    test('with nothing pending a launch only reads the list', () async {
      final access = await build();
      await access.refresh();
      expect(api.reads, 1);
      expect(api.refreshCalls, 0);
    });

    test('it stays inside the limit of 6 calls in 60 seconds', () async {
      await (await build()).purchaseStarted();
      api.refreshes = [_unknownAnswer];
      final access = await build();
      for (var i = 0; i < 20; i++) {
        await access.refresh(force: true);
        now = now.add(const Duration(seconds: 1));
      }
      expect(api.refreshCalls, lessThan(ProPackAccess.refreshLimit));
    });

    test('a launch read that hangs holds nothing else up', () async {
      await (await build()).purchaseStarted();
      final gated = GatedPacksApi();
      final access = await build(relayApi: gated);
      // Launch does not wait on this.
      final reading = access.refresh();
      await settle();
      expect(gated.reads, hasLength(1));

      // A registration goes through while the read is still out.
      await access.relayAnswered(
        accountId: 'acc_1',
        packs: const [proPack],
        request: access.beginRelayRequest(),
      );
      expect(access.isHeld, isTrue);
      gated.reads.single.completeError(Exception('timeout'));
      await reading;
      expect(access.isHeld, isTrue);
    });
  });

  group('a kept pack with an end date', () {
    StoredPacks kept(DateTime expires, {DateTime? answeredAt}) => StoredPacks(
      accountId: 'acc_1',
      packs: [AccountPack(id: 'pro', expiresAt: _seconds(expires))],
      answeredAt: answeredAt,
    );

    setUp(() => api.packs = null);

    test('no end date never ends on the phone', () async {
      store.kept = _keptForOne;
      final access = await build();
      now = now.add(const Duration(days: 3650));
      expect(access.isHeld, isTrue);
      await settle();
      expect(api.reads, 0);
    });

    test('before the date: held', () async {
      store.kept = kept(now.add(const Duration(days: 1)));
      final access = await build();
      expect(access.isHeld, isTrue);
      await settle();
      expect(api.reads, 0);
    });

    test(
      'just past the date with no network: still held, and it asks',
      () async {
        store.kept = kept(
          now.subtract(const Duration(hours: 1)),
          answeredAt: now.subtract(const Duration(days: 20)),
        );
        final access = await build();
        expect(access.isHeld, isTrue);
        await settle();
        expect(api.reads, 1, reason: 'seeing a past date asks the relay');
      },
    );

    test('held up to three days past the date, and not after', () async {
      final expires = now;
      store.kept = kept(
        expires,
        answeredAt: now.subtract(const Duration(days: 20)),
      );
      final access = await build();
      now = expires
          .add(ProPackAccess.expiredGrace)
          .subtract(const Duration(minutes: 1));
      expect(access.isHeld, isTrue);
      now = expires.add(ProPackAccess.expiredGrace);
      expect(access.isHeld, isFalse);
      expect(ProPackAccess.expiredGrace, const Duration(days: 3));
    });

    test('the stream says so when the grace runs out on a read', () async {
      store.kept = kept(now);
      final access = await build();
      expect(access.isHeld, isTrue);
      final seen = <bool>[];
      final sub = access.stream.listen(seen.add);
      now = now.add(const Duration(days: 4));
      await access.refresh();
      await settle();
      expect(seen, [false]);
      await sub.cancel();
    });

    test('someone who renewed gets the new date on the next answer', () async {
      store.kept = kept(now.subtract(const Duration(days: 2)));
      api.packs = PacksAnswer(
        packs: [
          AccountPack(
            id: 'pro',
            expiresAt: _seconds(now.add(const Duration(days: 30))),
          ),
        ],
      );
      final access = await build();
      await access.refresh();
      now = now.add(const Duration(days: 10));
      expect(access.isHeld, isTrue);
    });

    test(
      'the relay still lists it after the date: the grace runs from the answer',
      () async {
        final expires = now.subtract(const Duration(days: 5));
        api.packs = PacksAnswer(
          packs: [AccountPack(id: 'pro', expiresAt: _seconds(expires))],
        );
        final access = await build();
        await access.refresh();
        expect(access.isHeld, isTrue, reason: 'the relay just said so');

        api.packs = null;
        now = now.add(const Duration(days: 2));
        expect(access.isHeld, isTrue);
        now = now.add(const Duration(days: 2));
        expect(access.isHeld, isFalse);
      },
    );

    test('the relay dropping it ends it at once', () async {
      store.kept = kept(now.subtract(const Duration(hours: 1)));
      api.packs = const PacksAnswer(packs: []);
      final access = await build();
      await access.refresh();
      expect(access.isHeld, isFalse);
    });
  });

  group('reading on launch and resume', () {
    test('a second read inside the window makes no call', () async {
      final access = await build();
      await access.refresh();
      now = now.add(const Duration(seconds: 59));
      await access.refresh();
      expect(api.reads, 1);
      now = now.add(const Duration(seconds: 1));
      await access.refresh();
      expect(api.reads, 2);
    });

    test('a forced read is made anyway', () async {
      final access = await build();
      await access.refresh();
      await access.refresh(force: true);
      expect(api.reads, 2);
    });

    test('two reads at once share one call', () async {
      final access = await build();
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
      final access = await build();
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.held);
      expect(access.isHeld, isTrue);
      expect(listsProPack(store.kept!.packs), isTrue);
    });

    test('confirmed and not listed: not held, and that is kept', () async {
      store.kept = _keptForOne;
      api.refreshes = [answer(confirmed: true, listed: false)];
      final access = await build();
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.notHeld);
      expect(access.isHeld, isFalse);
      expect(store.kept?.packs, isEmpty);
    });

    test('not confirmed and listed: held and kept', () async {
      api.refreshes = [answer(confirmed: false, listed: true)];
      final access = await build();
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.held);
      expect(access.isHeld, isTrue);
    });

    test(
      'not confirmed and not listed: unknown, and what was held stays',
      () async {
        store.kept = _keptForOne;
        api.refreshes = [answer(confirmed: false, listed: false)];
        final access = await build();
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
        final access = await build();
        final outcome = await access.confirmWithStore();
        expect(outcome, ProPackRefreshOutcome.unknown);
        expect(outcome, isNot(ProPackRefreshOutcome.notHeld));
        expect(store.kept, isNull, reason: 'nothing was concluded or written');
      },
    );

    test('a call that fails is unknown and changes nothing', () async {
      store.kept = _keptForOne;
      api.refreshes = [null];
      final access = await build();
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.unknown);
      expect(access.isHeld, isTrue);
    });

    test('with no account known nothing is asked', () async {
      accountId = null;
      api.refreshes = [answer(confirmed: true, listed: true)];
      final access = await build();
      expect(await access.confirmWithStore(), ProPackRefreshOutcome.unknown);
      expect(api.refreshCalls, 0);
      expect(access.isHeld, isFalse);
    });

    test('stays under the limit of 6 calls in 60 seconds', () async {
      api.refreshes = [answer(confirmed: false, listed: false)];
      final access = await build();
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

  group('the stream', () {
    test('carries changes and only changes', () async {
      final devSwitch = ValueNotifier<bool>(false);
      final access = await build(
        override: DevProPackOverride()..watch(devSwitch),
      );
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
