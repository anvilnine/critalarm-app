import 'dart:async';

import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/access/own_server.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'access_fakes.dart';

void main() {
  group('Holdings.ready', () {
    test('waits for every source', () async {
      final hostedRead = Completer<void>();
      final proRead = Completer<void>();
      final holdings = Holdings([
        FakeHoldingSource(Holding.hosted)..ready = hostedRead.future,
        FakeHoldingSource(Holding.pro)..ready = proRead.future,
      ]);
      addTearDown(holdings.dispose);

      var isReady = false;
      unawaited(holdings.ready.then((_) => isReady = true));
      await settle();
      expect(isReady, isFalse);

      hostedRead.complete();
      await settle();
      expect(isReady, isFalse);

      proRead.complete();
      await settle();
      expect(isReady, isTrue);
    });

    test(
      'holdsOnceReady answers with what the source says after its read',
      () async {
        final read = Completer<void>();
        final hosted = FakeHoldingSource(Holding.hosted)..ready = read.future;
        final holdings = Holdings([hosted]);
        addTearDown(holdings.dispose);
        expect(holdings.holds(Holding.hosted), isFalse);

        final answer = holdings.holdsOnceReady(Holding.hosted);
        hosted.set(HoldingState.held);
        read.complete();
        expect(await answer, isTrue);
      },
    );

    test('holdsConfirmed leaves out a purchase that is still pending', () {
      final pro = FakeHoldingSource(Holding.pro, HoldingState.pending);
      final holdings = Holdings([pro]);
      addTearDown(holdings.dispose);
      expect(holdings.holds(Holding.pro), isTrue);
      expect(holdings.holdsConfirmed(Holding.pro), isFalse);

      pro.set(HoldingState.held);
      expect(holdings.holdsConfirmed(Holding.pro), isTrue);
    });
  });

  group('FeatureAccess.ready', () {
    test('waits for the holdings and for the saved server mode', () async {
      final sourceRead = Completer<void>();
      final modeRead = Completer<void>();
      final hosted = FakeHoldingSource(Holding.hosted)
        ..ready = sourceRead.future;
      final holdings = Holdings([hosted]);
      final access = FeatureAccess(
        holdings: holdings,
        serverModeRead: modeRead.future,
      );
      addTearDown(access.dispose);
      addTearDown(holdings.dispose);

      FeatureDecision? decided;
      unawaited(
        access.decideOnceReady(AppFeature.longHistory).then((d) => decided = d),
      );
      await settle();
      expect(decided, isNull);

      sourceRead.complete();
      await settle();
      expect(decided, isNull, reason: 'the mode is not read yet');

      // The saved session turns out to be a server of the user's own.
      access.setServerMode(ServerMode.selfhosted);
      modeRead.complete();
      await settle();
      expect(decided, const FeatureDecision.open());
    });

    test('a server mode that could not be read does not block it', () async {
      final access = TestAccess();
      addTearDown(access.dispose);
      final failing = FeatureAccess(
        holdings: access.holdings,
        serverModeRead: Future<void>.error(StateError('prefs')),
      );
      addTearDown(failing.dispose);
      expect(await failing.canOnceReady(AppFeature.appIcons), isFalse);
    });

    test('with nothing to wait for it is done at once', () async {
      final access = TestAccess(held: {Holding.hosted});
      addTearDown(access.dispose);
      expect(await access.features.canOnceReady(AppFeature.appIcons), isTrue);
    });
  });

  group('isPlanRead', () {
    test('is false until ready completes, then true', () async {
      final read = Completer<void>();
      final hosted = FakeHoldingSource(Holding.hosted)..ready = read.future;
      final holdings = Holdings([hosted]);
      final access = FeatureAccess(holdings: holdings);
      addTearDown(access.dispose);
      addTearDown(holdings.dispose);

      // The first ask starts the read.
      expect(access.isPlanRead, isFalse);
      await settle();
      expect(access.isPlanRead, isFalse);
      expect(access.planRead.value, isFalse);

      read.complete();
      await settle();
      expect(access.isPlanRead, isTrue);
      expect(access.planRead.value, isTrue);
    });

    test('also waits for the saved server mode', () async {
      final holder = TestAccess();
      addTearDown(holder.dispose);
      final modeRead = Completer<void>();
      final access = FeatureAccess(
        holdings: holder.holdings,
        serverModeRead: modeRead.future,
      );
      addTearDown(access.dispose);

      expect(access.isPlanRead, isFalse);
      await settle();
      expect(access.isPlanRead, isFalse);
      modeRead.complete();
      await settle();
      expect(access.isPlanRead, isTrue);
    });

    test('is true once a caller has awaited ready', () async {
      final read = Completer<void>();
      final hosted = FakeHoldingSource(Holding.hosted)..ready = read.future;
      final holdings = Holdings([hosted]);
      final access = FeatureAccess(holdings: holdings);
      addTearDown(access.dispose);
      addTearDown(holdings.dispose);

      final waiting = access.ready;
      read.complete();
      await waiting;
      expect(access.isPlanRead, isTrue);
    });

    test('planRead notifies once, and not again for a later ready', () async {
      final read = Completer<void>();
      final hosted = FakeHoldingSource(Holding.hosted)..ready = read.future;
      final holdings = Holdings([hosted]);
      final access = FeatureAccess(holdings: holdings);
      addTearDown(access.dispose);
      addTearDown(holdings.dispose);
      final seen = <bool>[];
      access.planRead.addListener(() => seen.add(access.planRead.value));

      read.complete();
      await settle();
      await access.ready;
      await access.ready;
      expect(seen, [true]);
    });

    test('a server mode that could not be read still reads the plan', () async {
      final holder = TestAccess();
      addTearDown(holder.dispose);
      final access = FeatureAccess(
        holdings: holder.holdings,
        serverModeRead: Future<void>.error(StateError('prefs')),
      );
      addTearDown(access.dispose);
      expect(access.isPlanRead, isFalse);
      await settle();
      expect(access.isPlanRead, isTrue);
    });
  });

  group('isOwnServer', () {
    test('is false on Crit Alarm Cloud, on the relay itself and while the '
        'mode is unknown', () {
      for (final mode in [ServerMode.hosted, ServerMode.relay, null]) {
        final access = TestAccess(serverMode: mode);
        addTearDown(access.dispose);
        expect(access.features.isOwnServer, isFalse, reason: '$mode');
      }
    });

    test('is true for a self-hosted server and nothing else', () {
      final access = TestAccess(serverMode: ServerMode.selfhosted);
      addTearDown(access.dispose);
      expect(access.features.isOwnServer, isTrue);
      for (final mode in [null, ...ServerMode.values]) {
        expect(
          isOwnServerMode(mode),
          mode == ServerMode.selfhosted,
          reason: '$mode',
        );
      }
    });

    test('once ready waits for the saved mode and never fails', () async {
      final holder = TestAccess();
      addTearDown(holder.dispose);
      final modeRead = Completer<void>();
      final access = FeatureAccess(
        holdings: holder.holdings,
        serverModeRead: modeRead.future,
      );
      addTearDown(access.dispose);
      bool? answer;
      unawaited(access.isOwnServerOnceReady().then((a) => answer = a));
      await settle();
      expect(answer, isNull);
      access.setServerMode(ServerMode.selfhosted);
      modeRead.completeError(StateError('prefs'));
      await settle();
      expect(answer, isTrue);
    });
  });

  group('decideHoldingNothing', () {
    test('names the holding to sell even when it is held', () {
      final access = TestAccess(held: {Holding.hosted, Holding.pro});
      addTearDown(access.dispose);
      expect(
        access.features.decideHoldingNothing(AppFeature.widgets),
        const FeatureDecision.locked(Holding.pro),
      );
      expect(
        access.features.decideHoldingNothing(AppFeature.weeklyCheck),
        const FeatureDecision.locked(Holding.hosted),
      );
      // Two holdings unlock the app icons. Hosted is the one named.
      expect(
        access.features.decideHoldingNothing(AppFeature.appIcons),
        const FeatureDecision.locked(Holding.hosted),
      );
    });

    test('is open where the server opens the feature, and not offered '
        'where the server has none', () {
      final access = TestAccess(serverMode: ServerMode.selfhosted);
      addTearDown(access.dispose);
      expect(
        access.features.decideHoldingNothing(AppFeature.appIcons),
        const FeatureDecision.open(),
      );
      expect(
        access.features.decideHoldingNothing(AppFeature.widgets),
        const FeatureDecision.locked(Holding.pro),
      );
      expect(
        access.features.decideHoldingNothing(AppFeature.weeklyCheck),
        const FeatureDecision.notOffered(),
      );
    });

    test('agrees with decide for every feature when nothing is held', () {
      for (final mode in [null, ...ServerMode.values]) {
        final access = TestAccess(serverMode: mode);
        addTearDown(access.dispose);
        for (final feature in AppFeature.values) {
          expect(
            access.features.decideHoldingNothing(feature),
            access.features.decide(feature),
            reason: '${feature.name} on $mode',
          );
        }
      }
    });
  });
}
