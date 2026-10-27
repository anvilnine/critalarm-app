import 'dart:async';

import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../access/access_fakes.dart';

void main() {
  late TestAccess access;

  tearDown(() => access.dispose());

  Future<String?> redirect() =>
      ownSoundsRouteRedirect(access.features, soundList: '/sounds');

  group('the record and crop routes', () {
    test('locked: the route goes to the sound list', () async {
      access = TestAccess();
      expect(await redirect(), '/sounds');
    });

    test('with Pro: the route opens', () async {
      access = TestAccess(held: {Holding.pro});
      expect(await redirect(), isNull);
    });

    test('a purchase being confirmed: the route opens', () async {
      access = TestAccess()..pro.set(HoldingState.pending);
      expect(await redirect(), isNull);
    });

    test('a plan that could not be read: the route opens', () async {
      access = TestAccess()..pro.set(HoldingState.unknown);
      expect(await redirect(), isNull);
      expect(
        await ownSoundsOnceReady(access.features),
        const FeatureDecision.unread(Holding.pro),
      );
    });

    test('Hosted without Pro: the route goes to the sound list', () async {
      access = TestAccess(held: {Holding.hosted});
      expect(await redirect(), '/sounds');
    });
  });

  group('asked before the plan is read', () {
    test('the answer waits, so a Pro holder is not turned away', () async {
      access = TestAccess();
      final read = Completer<void>();
      final pro = FakeHoldingSource(Holding.pro)..ready = read.future;
      final holdings = Holdings([FakeHoldingSource(Holding.hosted), pro]);
      final features = FeatureAccess(
        holdings: holdings,
        serverMode: ServerMode.hosted,
      );
      addTearDown(features.dispose);
      addTearDown(holdings.dispose);

      String? answer = 'not answered';
      unawaited(
        ownSoundsRouteRedirect(
          features,
          soundList: '/sounds',
        ).then((value) => answer = value),
      );
      await settle();
      expect(answer, 'not answered');

      pro.set(HoldingState.held);
      read.complete();
      await settle();
      expect(answer, isNull);
    });
  });
}
