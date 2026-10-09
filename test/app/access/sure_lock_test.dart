import 'dart:async';

import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/app/access/sure_lock.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_guard.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/paywall/data/repositories/in_memory_subscription_repository.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _free = DeviceIdentity(deviceId: 'd1', accountId: 'acc_1');
const _paid = DeviceIdentity(deviceId: 'd1', accountId: 'acc_1', tier: 'pro');

/// A store that cannot be reached.
class _DownStore extends InMemorySubscriptionRepository {
  @override
  Future<AppResult<bool>> isProActive() async => throw StateError('offline');
}

void main() {
  late PlanChanges plan;
  late Completer<DeviceIdentity?> identityRead;
  late Completer<void> modeRead;
  late FeatureAccess access;

  /// The lock as `di.dart` builds it. The stored identity and the saved
  /// server mode both land when the test says so, the way they do on a
  /// cold start.
  SureLock build({
    SubscriptionRepository? store,
    ServerMode? serverMode,
  }) {
    final source = HostedHoldingSource(
      readIdentity: () => identityRead.future,
      planChanges: plan,
      proOverride: const NoProOverride(),
      readStore: store == null ? null : () => store,
    );
    final holdings = Holdings([source]);
    access = FeatureAccess(
      holdings: holdings,
      serverMode: serverMode,
      serverModeRead: modeRead.future,
    );
    addTearDown(() async {
      await access.dispose();
      await holdings.dispose();
      source.dispose();
    });
    return SureLock(access: access, hosted: source);
  }

  setUp(() {
    plan = PlanChanges();
    identityRead = Completer();
    modeRead = Completer();
  });

  group('a cold start', () {
    test('says nothing until the tier and the server mode are read', () async {
      final lock = build(serverMode: ServerMode.hosted);
      // The plain answer is "locked" this early: nothing is read yet.
      expect(access.can(AppFeature.appIcons), isFalse);

      bool? answer;
      unawaited(lock.isLocked(AppFeature.appIcons).then((a) => answer = a));
      await pumpEventQueue();
      expect(answer, isNull, reason: 'the tier is not read yet');

      identityRead.complete(_paid);
      await pumpEventQueue();
      expect(answer, isNull, reason: 'the server mode is not read yet');

      modeRead.complete();
      await pumpEventQueue();
      expect(answer, isFalse, reason: 'Hosted is held');
    });

    test('does not lock a phone on its own server before the session is '
        'read', () async {
      final lock = build();
      bool? answer;
      unawaited(lock.isLocked(AppFeature.appIcons).then((a) => answer = a));
      identityRead.complete(_free);
      await pumpEventQueue();
      expect(answer, isNull);

      access.setServerMode(ServerMode.selfhosted);
      modeRead.complete();
      await pumpEventQueue();
      expect(answer, isFalse);
    });

    test('the app icon guard keeps a paying person on their icon', () async {
      final lock = build(serverMode: ServerMode.hosted);
      var applied = 0;
      final guard = AppIconGuard(
        readCurrent: () async => AppIcon.crowned,
        apply: (_) async {
          applied++;
          return true;
        },
        readUnlocked: () async => !await lock.isLocked(AppFeature.appIcons),
      );

      final checking = guard.check();
      await pumpEventQueue();
      expect(applied, 0, reason: 'nothing reverts while the plan is unread');

      identityRead.complete(_paid);
      modeRead.complete();
      expect(await checking, isNull);
      expect(applied, 0);
    });
  });

  group('once everything is read', () {
    setUp(() {
      identityRead.complete(_free);
      modeRead.complete();
    });

    test(
      'free on Crit Alarm Cloud with a store that says no is locked',
      () async {
        final lock = build(
          store: InMemorySubscriptionRepository(),
          serverMode: ServerMode.hosted,
        );
        expect(await lock.isLocked(AppFeature.appIcons), isTrue);
      },
    );

    test('the store saying Hosted is active keeps it open, though the tier '
        'still says free', () async {
      final lock = build(
        store: InMemorySubscriptionRepository(isPro: true),
        serverMode: ServerMode.hosted,
      );
      expect(await lock.isLocked(AppFeature.appIcons), isFalse);
    });

    test('a store that cannot answer keeps it open', () async {
      final lock = build(store: _DownStore(), serverMode: ServerMode.hosted);
      expect(await lock.isLocked(AppFeature.appIcons), isFalse);
    });

    test(
      'a build with no store has nobody to ask, so the tier stands',
      () async {
        final lock = build(serverMode: ServerMode.hosted);
        expect(await lock.isLocked(AppFeature.appIcons), isTrue);
      },
    );

    test('the store flag mirrored into the plan keeps it open', () async {
      plan.setStoreSaysPro(value: true);
      final lock = build(
        store: InMemorySubscriptionRepository(),
        serverMode: ServerMode.hosted,
      );
      expect(await lock.isLocked(AppFeature.appIcons), isFalse);
    });

    test("a server of the user's own is never locked", () async {
      final lock = build(
        store: InMemorySubscriptionRepository(),
        serverMode: ServerMode.selfhosted,
      );
      expect(await lock.isLocked(AppFeature.appIcons), isFalse);
    });

    test(
      'the relay itself has plans, so it locks like Crit Alarm Cloud',
      () async {
        final lock = build(
          store: InMemorySubscriptionRepository(),
          serverMode: ServerMode.relay,
        );
        expect(await lock.isLocked(AppFeature.appIcons), isTrue);
      },
    );

    test('a phone connected to nothing is never locked for sure', () async {
      final lock = build(store: InMemorySubscriptionRepository());
      // The picker draws the lock, and nothing is taken away.
      expect(access.can(AppFeature.appIcons), isFalse);
      expect(await lock.isLocked(AppFeature.appIcons), isFalse);
    });

    test(
      'the store is not asked about a feature Hosted does not unlock',
      () async {
        final lock = build(
          store: InMemorySubscriptionRepository(isPro: true),
          serverMode: ServerMode.hosted,
        );
        expect(await lock.isLocked(AppFeature.weeklyCheck), isTrue);
      },
    );
  });
}
