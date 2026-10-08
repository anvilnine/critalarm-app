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
  AppFeature.storageRules,
  AppFeature.appIcons,
  AppFeature.widgets,
];

const List<AppFeature> _proFeatures = [
  AppFeature.ownSounds,
  AppFeature.alarmScreenStyles,
  AppFeature.wakeUpChallenges,
  AppFeature.weeklyCheck,
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
      expect(
        access.decide(AppFeature.weeklyCheck),
        const FeatureDecision.open(),
      );
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
    test('is true for open and confirming, false for locked', () {
      expect(const FeatureDecision.open().isUsable, isTrue);
      expect(const FeatureDecision.confirming(Holding.pro).isUsable, isTrue);
      expect(const FeatureDecision.locked(Holding.pro).isUsable, isFalse);
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

    test("relay mode is a server of the user's own", () {
      final access = build(serverMode: ServerMode.relay);
      expect(access.can(AppFeature.longHistory), isTrue);
      expect(access.can(AppFeature.weeklyCheck), isFalse);
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
      expect(heard, _proFeatures);
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

      // Both are a server of the user's own, so nothing moves.
      access.setServerMode(ServerMode.relay);
      await settle();
      expect(heard, isEmpty);
    });

    test('a mode change is quiet for a feature already held', () async {
      hosted.set(HoldingState.held);
      await settle();
      heard.clear();
      access.setServerMode(ServerMode.selfhosted);
      await settle();
      expect(heard, isEmpty);
    });
  });
}
