import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'access_fakes.dart';

const List<AppFeature> _hostedFeatures = [
  AppFeature.unlimitedCriticalTopics,
  AppFeature.longHistory,
  AppFeature.appIcons,
  AppFeature.weeklyCheck,
];

/// What Pro alone unlocks. The app icons are not here: Hosted unlocks them
/// too, so they are in neither "only" list below where that matters.
const List<AppFeature> _proFeatures = [
  AppFeature.widgets,
  AppFeature.ownSounds,
  AppFeature.alarmScreenStyles,
  AppFeature.wakeUpChallenges,
];

/// What a server of the user's own opens by itself.
const List<AppFeature> _openOnOwnServer = [
  AppFeature.unlimitedCriticalTopics,
  AppFeature.longHistory,
  AppFeature.appIcons,
];

void main() {
  late FakeHoldingSource hosted;
  late FakeHoldingSource pro;
  late Holdings holdings;

  FeatureAccess build({
    ServerMode? serverMode,
    Map<AppFeature, FeatureRule> table = featureTable,
  }) {
    final access = FeatureAccess(
      holdings: holdings,
      table: table,
      serverMode: serverMode,
    );
    addTearDown(access.dispose);
    return access;
  }

  setUp(() {
    hosted = FakeHoldingSource(Holding.hosted);
    pro = FakeHoldingSource(Holding.pro);
    holdings = Holdings([hosted, pro]);
    addTearDown(holdings.dispose);
  });

  group('a pending purchase', () {
    test('gives confirming, and confirming counts as usable', () {
      final access = build(serverMode: ServerMode.hosted);
      pro.set(HoldingState.pending);
      for (final feature in _proFeatures) {
        expect(
          access.decide(feature),
          const FeatureDecision.confirming(Holding.pro),
          reason: feature.name,
        );
        expect(access.can(feature), isTrue, reason: feature.name);
      }
      // Pro waiting says nothing about a Hosted feature.
      expect(
        access.decide(AppFeature.longHistory),
        const FeatureDecision.locked(Holding.hosted),
      );

      hosted.set(HoldingState.pending);
      for (final feature in _hostedFeatures) {
        expect(
          access.decide(feature),
          const FeatureDecision.confirming(Holding.hosted),
          reason: feature.name,
        );
        expect(access.can(feature), isTrue, reason: feature.name);
      }
    });

    test('becomes open once it is held', () {
      final access = build();
      pro
        ..set(HoldingState.pending)
        ..set(HoldingState.held);
      expect(access.decide(AppFeature.widgets), const FeatureDecision.open());
    });

    test('is open, not confirming, where the server opens the feature', () {
      final access = build(serverMode: ServerMode.selfhosted);
      hosted.set(HoldingState.pending);
      expect(
        access.decide(AppFeature.appIcons),
        const FeatureDecision.open(),
      );
    });
  });

  group('isUsable', () {
    test('is true for open, confirming and unread, false for locked and '
        'not offered', () {
      expect(const FeatureDecision.open().isUsable, isTrue);
      expect(const FeatureDecision.confirming(Holding.pro).isUsable, isTrue);
      expect(const FeatureDecision.unread(Holding.pro).isUsable, isTrue);
      expect(const FeatureDecision.locked(Holding.pro).isUsable, isFalse);
      expect(const FeatureDecision.notOffered().isUsable, isFalse);
    });
  });

  group("not offered on a server of the user's own", () {
    const notOffered = FeatureDecision.notOffered();

    test('is its own answer: not open, and not a lock with something to '
        'sell', () {
      expect(notOffered, isNot(const FeatureDecision.open()));
      expect(notOffered, isNot(isA<FeatureLocked>()));
      expect(notOffered, const FeatureDecision.notOffered());
      expect(notOffered.toString(), 'FeatureDecision.notOffered');
    });

    test('the weekly check is not offered there whatever is held, pending '
        'or unread', () {
      final access = build(serverMode: ServerMode.selfhosted);
      for (final hostedState in HoldingState.values) {
        for (final proState in HoldingState.values) {
          hosted.set(hostedState);
          pro.set(proState);
          expect(
            access.decide(AppFeature.weeklyCheck),
            notOffered,
            reason: 'hosted ${hostedState.name}, pro ${proState.name}',
          );
          expect(access.can(AppFeature.weeklyCheck), isFalse);
        }
      }
    });

    test('holding nothing, it is still not offered: there is no lock to '
        'draw and nothing to sell', () {
      final access = build(serverMode: ServerMode.selfhosted);
      expect(access.decideHoldingNothing(AppFeature.weeklyCheck), notOffered);
      access.setServerMode(ServerMode.hosted);
      expect(
        access.decideHoldingNothing(AppFeature.weeklyCheck),
        const FeatureDecision.locked(Holding.hosted),
      );
    });

    test('asked once ready, it answers and does not throw, even with the '
        'plan unread', () async {
      final access = build(serverMode: ServerMode.selfhosted);
      hosted.set(HoldingState.unknown);
      expect(
        await access.decideOnceReady(AppFeature.weeklyCheck),
        notOffered,
      );
      expect(await access.canOnceReady(AppFeature.weeklyCheck), isFalse);
      expect(await access.usableOnceReady(AppFeature.weeklyCheck), isFalse);
    });

    test('is never said while the server is not known, or for the relay: '
        'both have plans', () {
      for (final mode in [null, ServerMode.relay, ServerMode.hosted]) {
        final access = build(serverMode: mode);
        expect(
          access.decide(AppFeature.weeklyCheck),
          const FeatureDecision.locked(Holding.hosted),
          reason: '$mode',
        );
      }
    });

    test('what such a server opens by itself stays open', () {
      final access = build(serverMode: ServerMode.selfhosted);
      for (final feature in _openOnOwnServer) {
        expect(
          access.decide(feature),
          const FeatureDecision.open(),
          reason: feature.name,
        );
      }
    });
  });

  group('the weekly check on Crit Alarm Cloud', () {
    test('Pro alone does not open it, and Hosted is what is offered', () {
      final access = build(serverMode: ServerMode.hosted);
      pro.set(HoldingState.held);
      expect(
        access.decide(AppFeature.weeklyCheck),
        const FeatureDecision.locked(Holding.hosted),
      );
      expect(access.can(AppFeature.weeklyCheck), isFalse);
    });

    test('Hosted opens it, with or without Pro', () {
      final access = build(serverMode: ServerMode.hosted);
      hosted.set(HoldingState.held);
      expect(access.can(AppFeature.weeklyCheck), isTrue);
      pro.set(HoldingState.held);
      expect(access.can(AppFeature.weeklyCheck), isTrue);
    });

    test('a lapse locks it again and a return opens it', () {
      final access = build(serverMode: ServerMode.hosted);
      hosted.set(HoldingState.held);
      expect(access.can(AppFeature.weeklyCheck), isTrue);
      hosted.set(HoldingState.notHeld);
      expect(
        access.decide(AppFeature.weeklyCheck),
        const FeatureDecision.locked(Holding.hosted),
      );
      hosted.set(HoldingState.held);
      expect(access.can(AppFeature.weeklyCheck), isTrue);
    });
  });

  group('the app icons', () {
    test('either holding opens them on Crit Alarm Cloud', () {
      final access = build(serverMode: ServerMode.hosted);
      expect(
        access.decide(AppFeature.appIcons),
        const FeatureDecision.locked(Holding.hosted),
      );
      pro.set(HoldingState.held);
      expect(access.can(AppFeature.appIcons), isTrue);
      pro.set(HoldingState.notHeld);
      hosted.set(HoldingState.held);
      expect(access.can(AppFeature.appIcons), isTrue);
    });

    test('a pending purchase of either one counts as confirming it', () {
      final access = build(serverMode: ServerMode.hosted);
      pro.set(HoldingState.pending);
      expect(
        access.decide(AppFeature.appIcons),
        const FeatureDecision.confirming(Holding.pro),
      );
    });

    test('one holding unread and the other not held is unread, never a '
        'lock', () {
      final access = build(serverMode: ServerMode.hosted);
      hosted.set(HoldingState.unknown);
      expect(
        access.decide(AppFeature.appIcons),
        const FeatureDecision.unread(Holding.hosted),
      );
    });
  });

  group('server mode', () {
    test('unknown answers as cloud', () {
      final access = build();
      expect(access.serverMode, isNull);
      for (final feature in _hostedFeatures) {
        expect(
          access.decide(feature),
          const FeatureDecision.locked(Holding.hosted),
          reason: feature.name,
        );
      }
    });

    test('relay mode is the relay itself, with plans, and follows what is '
        'held', () {
      final access = build(serverMode: ServerMode.relay);
      expect(access.isOwnServer, isFalse);
      expect(access.can(AppFeature.longHistory), isFalse);
      hosted.set(HoldingState.held);
      expect(access.can(AppFeature.longHistory), isTrue);
      expect(access.can(AppFeature.weeklyCheck), isTrue);
      expect(access.can(AppFeature.widgets), isFalse);
    });

    test('a new mode changes the answers at once', () {
      final access = build(serverMode: ServerMode.hosted);
      expect(access.can(AppFeature.appIcons), isFalse);
      access.setServerMode(ServerMode.selfhosted);
      expect(access.serverMode, ServerMode.selfhosted);
      expect(access.can(AppFeature.appIcons), isTrue);
      access.setServerMode(null);
      expect(access.can(AppFeature.appIcons), isFalse);
    });
  });

  group('the table', () {
    test('a feature with no row is open to everyone', () {
      final access = build(table: const {});
      for (final feature in AppFeature.values) {
        expect(access.decide(feature), const FeatureDecision.open());
      }
    });

    test('any one of several holdings unlocks, and the first is offered', () {
      final access = build(
        table: const {
          AppFeature.widgets: FeatureRule(
            unlockedBy: {Holding.pro, Holding.hosted},
            onOwnServer: OwnServerRule.sameAsCloud,
          ),
        },
      );
      expect(
        access.decide(AppFeature.widgets),
        const FeatureDecision.locked(Holding.pro),
      );
      hosted.set(HoldingState.pending);
      expect(
        access.decide(AppFeature.widgets),
        const FeatureDecision.confirming(Holding.hosted),
      );
      hosted.set(HoldingState.held);
      expect(access.decide(AppFeature.widgets), const FeatureDecision.open());
    });
  });

  group('changes', () {
    late List<AppFeature> heard;
    late FeatureAccess access;

    setUp(() {
      access = build(serverMode: ServerMode.hosted);
      heard = [];
      access.changes.listen(heard.add);
    });

    test('names the features a holding unlocked, and no others', () async {
      pro.set(HoldingState.held);
      await settle();
      // The app icons too: either holding unlocks them.
      expect(heard, [AppFeature.appIcons, ..._proFeatures]);
    });

    test('names a feature again when confirming becomes open', () async {
      hosted.set(HoldingState.pending);
      await settle();
      expect(heard, _hostedFeatures);
      heard.clear();
      hosted.set(HoldingState.held);
      await settle();
      expect(heard, _hostedFeatures);
    });

    test('is quiet when nothing changed', () async {
      pro.ringOnly();
      hosted.ringOnly();
      access
        ..setServerMode(ServerMode.hosted)
        ..setServerMode(ServerMode.hosted);
      await settle();
      expect(heard, isEmpty);
    });

    test('a new server mode names only the features it moved', () async {
      access.setServerMode(ServerMode.selfhosted);
      await settle();
      expect(heard, _hostedFeatures);
      heard.clear();

      // The relay has plans like Crit Alarm Cloud, so they lock again.
      access.setServerMode(ServerMode.relay);
      await settle();
      expect(heard, _hostedFeatures);
      heard.clear();

      // Cloud and the relay answer the same, so nothing moves.
      access.setServerMode(ServerMode.hosted);
      await settle();
      expect(heard, isEmpty);
    });

    test('a mode change is quiet for a feature already held, and names '
        'the one that is not offered there', () async {
      hosted.set(HoldingState.held);
      await settle();
      heard.clear();
      access.setServerMode(ServerMode.selfhosted);
      await settle();
      expect(heard, [AppFeature.weeklyCheck]);
    });
  });
}
