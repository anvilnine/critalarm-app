import 'dart:async';

import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/app/access/pro_holding_source.dart';
import 'package:critalarm/app/access/sure_lock.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_guard.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/day0_card_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminders_sheet_choice.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/presentation/cubits/pro_status_cubit.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/access/access_fakes.dart';
import '../../features/pro_pack/pro_pack_fakes.dart' hide settle;
import '../../features/topics/support/home_setup_fakes.dart'
    show FakeFirstMessageStore;
import '../../helpers/fake_in_app_notice_repository.dart';

const _free = DeviceIdentity(deviceId: 'd1', accountId: 'acc_1');
const _paid = DeviceIdentity(deviceId: 'd1', accountId: 'acc_1', tier: 'pro');

/// The account repository as `di.dart` wires its one plan read: straight
/// through to `Holdings`.
class _Account implements AccountRepository {
  _Account(this._holdings);

  final Holdings _holdings;

  @override
  Future<bool> readHoldsHosted() => _holdings.holdsOnceReady(Holding.hosted);

  @override
  Future<ServerMode?> readServerMode() async => ServerMode.hosted;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('a holding that could not be read', () {
    late TestAccess access;

    setUp(() {
      access = TestAccess()..hosted.set(HoldingState.unknown);
      addTearDown(access.dispose);
    });

    test('is not held, and is not "not held" either', () {
      expect(access.holdings.holds(Holding.hosted), isFalse);
      expect(access.holdings.holdsConfirmed(Holding.hosted), isFalse);
      expect(access.holdings.isUnknown(Holding.hosted), isTrue);
      expect(access.holdings.held, isEmpty);
      expect(access.holdings.isUnknown(Holding.pro), isFalse);
    });

    test('the once-ready ask throws, one way everywhere', () async {
      await expectLater(
        access.holdings.holdsOnceReady(Holding.hosted),
        throwsA(
          isA<HoldingUnreadable>().having(
            (e) => e.holding,
            'holding',
            Holding.hosted,
          ),
        ),
      );
      await expectLater(
        access.features.decideOnceReady(AppFeature.widgets),
        throwsA(isA<HoldingUnreadable>()),
      );
      await expectLater(
        access.features.canOnceReady(AppFeature.appIcons),
        throwsA(isA<HoldingUnreadable>()),
      );
      // The other holding was read. Its answers are not held up.
      expect(await access.holdings.holdsOnceReady(Holding.pro), isFalse);
      expect(
        await access.features.canOnceReady(AppFeature.weeklyCheck),
        isFalse,
      );
    });

    test('never locks a feature and never sells one', () {
      for (final feature in AppFeature.values) {
        final decision = access.features.decide(feature);
        if (featureTable[feature]!.unlockedBy.contains(Holding.hosted)) {
          expect(
            decision,
            const FeatureDecision.unread(Holding.hosted),
            reason: feature.name,
          );
          expect(decision.isUsable, isTrue);
          for (final source in LockSource.values) {
            expect(paywallLocationFor(decision, source), isNull);
          }
        } else {
          expect(decision, isA<FeatureLocked>(), reason: feature.name);
        }
      }
    });

    test('a screen that draws gets "usable" and no error', () async {
      expect(
        await access.features.usableOnceReady(AppFeature.longHistory),
        isTrue,
      );
      expect(
        await access.features.usableOnceReady(AppFeature.weeklyCheck),
        isFalse,
      );
    });

    test('is announced when it clears', () async {
      final heard = <AppFeature>[];
      access.features.changes.listen(heard.add);
      access.hosted.set(HoldingState.notHeld);
      await settle();
      expect(heard, contains(AppFeature.appIcons));
      expect(
        access.features.decide(AppFeature.appIcons),
        const FeatureDecision.locked(Holding.hosted),
      );
    });

    test("a server of the user's own is open all the same", () {
      access.features.setServerMode(ServerMode.selfhosted);
      expect(
        access.features.decide(AppFeature.appIcons),
        const FeatureDecision.open(),
      );
    });

    test('a second source that knows wins over one that does not', () {
      final holdings = Holdings([
        FakeHoldingSource(Holding.hosted, HoldingState.unknown),
        FakeHoldingSource(Holding.hosted),
      ]);
      addTearDown(holdings.dispose);
      expect(holdings.stateOf(Holding.hosted), HoldingState.notHeld);
    });
  });

  group('the Hosted source', () {
    late PlanChanges plan;
    late ValueNotifier<bool> devSwitch;
    late bool isFailing;
    late DeviceIdentity stored;
    late int reads;

    HostedHoldingSource build() {
      final source = HostedHoldingSource(
        readIdentity: () async {
          reads++;
          if (isFailing) throw StateError('keychain_read');
          return stored;
        },
        planChanges: plan,
        proOverride: DevProOverride()..watch(devSwitch),
      );
      addTearDown(source.dispose);
      return source;
    }

    setUp(() {
      plan = PlanChanges();
      devSwitch = ValueNotifier(false);
      isFailing = false;
      stored = _paid;
      reads = 0;
    });

    test('is unknown, not "not held", when its first read fails', () async {
      isFailing = true;
      final source = build();
      // Before the read lands it is the plain cold-start answer.
      expect(source.state, HoldingState.notHeld);
      await source.ready;
      expect(source.state, HoldingState.unknown);
    });

    test('reads again on the next ask, and recovers', () async {
      isFailing = true;
      final source = build();
      await source.ready;
      expect(reads, 1);
      expect(source.state, HoldingState.unknown);

      // Still locked: each ask tries once more and nobody is left hanging.
      await source.ready;
      expect(reads, 2);
      expect(source.state, HoldingState.unknown);

      // The phone was unlocked. Nothing announces that. The next ask finds
      // out.
      isFailing = false;
      var rings = 0;
      source.changes.addListener(() => rings++);
      await source.ready;
      expect(reads, 3);
      expect(source.state, HoldingState.held);
      expect(rings, greaterThan(0));

      // A good answer is not read again on every ask.
      await source.ready;
      expect(reads, 3);
    });

    test('a failed read never replaces a good earlier one', () async {
      final source = build();
      await source.ready;
      expect(source.state, HoldingState.held);

      isFailing = true;
      plan.bump();
      await source.ready;
      expect(source.state, HoldingState.held);
    });

    test('a good read is kept when the read after it fails', () async {
      final first = Completer<DeviceIdentity>();
      final second = Completer<DeviceIdentity>();
      final answers = [first, second];
      var asked = 0;
      final source = HostedHoldingSource(
        readIdentity: () => answers[asked++].future,
        planChanges: plan,
        proOverride: const NoProOverride(),
      );
      addTearDown(source.dispose);
      // A second read starts while the first is still out.
      plan.bump();
      expect(asked, 2);

      second.completeError(StateError('keychain_read'));
      await pumpEventQueue();
      expect(source.state, HoldingState.unknown);

      first.complete(_paid);
      await pumpEventQueue();
      expect(source.state, HoldingState.held);
    });

    test('an older answer does not replace a newer one', () async {
      final first = Completer<DeviceIdentity>();
      final second = Completer<DeviceIdentity>();
      final answers = [first, second];
      var asked = 0;
      final source = HostedHoldingSource(
        readIdentity: () => answers[asked++].future,
        planChanges: plan,
        proOverride: const NoProOverride(),
      );
      addTearDown(source.dispose);
      plan.bump();
      second.complete(_free);
      await pumpEventQueue();
      first.complete(_paid);
      await pumpEventQueue();
      expect(source.state, HoldingState.notHeld);
    });

    test(
      'the store and the developer switch still answer on their own',
      () async {
        isFailing = true;
        final source = build();
        await source.ready;
        plan.setStoreSaysPro(value: true);
        expect(source.state, HoldingState.pending);
        devSwitch.value = true;
        expect(source.state, HoldingState.held);
      },
    );

    test('the rule: an unread identity is unknown, whatever its tier', () {
      expect(
        HostedHoldingSource.stateFor(
          identity: null,
          storeSaysPro: false,
          isForcingPro: false,
          isIdentityUnread: true,
        ),
        HoldingState.unknown,
      );
      expect(
        HostedHoldingSource.stateFor(
          identity: null,
          storeSaysPro: false,
          isForcingPro: false,
        ),
        HoldingState.notHeld,
      );
    });
  });

  group('the Pro source', () {
    late FakePacksApi api;
    late MemoryProPackStore store;
    late AccountIdentityChanges identityChanges;
    late bool isFailing;
    String? accountId;
    late int reads;

    ProPackAccess buildAccess() {
      final access = ProPackAccess(
        api: api,
        store: store,
        readAccountId: () async {
          reads++;
          if (isFailing) throw StateError('keychain_read');
          return accountId;
        },
        identityChanges: [identityChanges],
        override: DevProPackOverride()..watch(ValueNotifier(false)),
      );
      addTearDown(access.dispose);
      return access;
    }

    setUp(() {
      api = FakePacksApi();
      store = MemoryProPackStore();
      identityChanges = AccountIdentityChanges();
      isFailing = false;
      accountId = 'acc_1';
      reads = 0;
    });

    test('is unknown while the account cannot be read, and tries again on '
        'the next ask', () async {
      isFailing = true;
      final source = ProHoldingSource(buildAccess());
      await source.ready;
      expect(source.state, HoldingState.unknown);
      expect(reads, 1);

      isFailing = false;
      await source.ready;
      expect(reads, 2);
      expect(source.state, HoldingState.notHeld);
    });

    test('an account that is simply not known yet is not held', () async {
      accountId = null;
      final source = ProHoldingSource(buildAccess());
      await source.ready;
      expect(source.state, HoldingState.notHeld);
    });

    test('ready follows the read an account switch started', () async {
      Completer<void>? gate;
      final access = ProPackAccess(
        api: api,
        store: store,
        readAccountId: () async {
          await gate?.future;
          return accountId;
        },
        identityChanges: [identityChanges],
        override: DevProPackOverride()..watch(ValueNotifier(false)),
      );
      addTearDown(access.dispose);
      final source = ProHoldingSource(access);
      await source.ready;

      // Sign-in to another account. Its read is still out.
      gate = Completer();
      identityChanges.bump();
      var isReady = false;
      unawaited(source.ready.then((_) => isReady = true));
      await pumpEventQueue();
      expect(isReady, isFalse, reason: 'the first sync alone is not enough');

      gate.complete();
      await pumpEventQueue();
      expect(isReady, isTrue);
    });
  });

  group('what each caller does when nobody knows', () {
    late bool isFailing;
    late HostedHoldingSource source;
    late Holdings holdings;
    late FeatureAccess features;

    setUp(() {
      isFailing = true;
      source = HostedHoldingSource(
        readIdentity: () async {
          if (isFailing) throw StateError('keychain_read');
          return _free;
        },
        planChanges: PlanChanges(),
        proOverride: const NoProOverride(),
      );
      holdings = Holdings([source]);
      features = FeatureAccess(
        holdings: holdings,
        serverMode: ServerMode.hosted,
      );
      addTearDown(() async {
        await features.dispose();
        await holdings.dispose();
        source.dispose();
      });
    });

    test('the sure lock throws, and the icon guard keeps the icon', () async {
      final lock = SureLock(access: features, hosted: source);
      await expectLater(
        lock.isLocked(AppFeature.appIcons),
        throwsA(isA<HoldingUnreadable>()),
      );

      var applied = 0;
      final guard = AppIconGuard(
        readCurrent: () async => AppIcon.crowned,
        apply: (_) async {
          applied++;
          return true;
        },
        readUnlocked: () async => !await lock.isLocked(AppFeature.appIcons),
      );
      expect(await guard.check(), isNull);
      expect(applied, 0);

      // Once it can be read, a free account does lose the icon.
      isFailing = false;
      expect(await guard.check(), AppIcon.standard);
    });

    test('the icon picker draws its locks and changes nothing', () async {
      var applied = 0;
      final cubit = AppIconCubit(
        readCurrent: () async => AppIcon.crowned,
        apply: (_) async {
          applied++;
          return true;
        },
        readUnlocked: () => features.canOnceReady(AppFeature.appIcons),
        planChanges: PlanChanges(),
      );
      addTearDown(cubit.close);
      await pumpEventQueue();
      expect(cubit.state.status, AppIconStatus.ready);
      expect(cubit.state.current, AppIcon.crowned);
      expect(cubit.state.unlocked, isFalse);
      expect(applied, 0);
    });

    test('the Pro ask is not shown', () async {
      final rules = ProAskRules(
        noticeRepository: FakeInAppNoticeRepository(),
        accountRepository: _Account(holdings),
      );
      expect(await rules.shouldAsk(), isFalse);
      isFailing = false;
      expect(await rules.shouldAsk(), isTrue);
    });

    test('the day-0 card is not shown', () async {
      final now = DateTime(2026, 10, 7, 10);
      final notices = FakeInAppNoticeRepository()
        ..now = (() => now)
        ..firstRealAcknowledgedAt = now.subtract(const Duration(days: 1));
      final rules = Day0CardRules(
        noticeRepository: notices,
        accountRepository: _Account(holdings),
        firstMessageStore: FakeFirstMessageStore()..isReceived = true,
        isWeb: false,
        now: () => now,
      );
      expect(await rules.next(isNewOpen: true), Day0CardDecision.none);
      isFailing = false;
      expect(await rules.next(isNewOpen: true), Day0CardDecision.start);
    });

    test('the reminders sheet turns no offers on for someone it cannot '
        'place', () async {
      // The sheet's reader counts a failed read as holding Hosted.
      Future<bool> readAsTheSheetDoes() async {
        try {
          return await _Account(holdings).readHoldsHosted();
        } on Object {
          return true;
        }
      }

      expect(await readAsTheSheetDoes(), isTrue);
      expect(
        LocalRemindersSheetChoice.turnOn(
          offersTicked: true,
          isSelfHosted: false,
          holdsHosted: await readAsTheSheetDoes(),
        ).offers,
        isFalse,
      );
    });

    test('the Pro badge stays off', () async {
      final cubit = ProStatusCubit(
        readHoldsHosted: () => holdings.holdsOnceReady(Holding.hosted),
        planChanges: PlanChanges(),
        identityChanges: AccountIdentityChanges(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state, isFalse);
    });
  });
}
