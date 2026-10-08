import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'access_fakes.dart';

const _open = FeatureDecision.open();

// Short names so the table below reads as a table: open, sell Hosted,
// sell Pro.
const FeatureDecision _o = _open;
const _h = FeatureDecision.locked(Holding.hosted);
const _p = FeatureDecision.locked(Holding.pro);

/// One row per feature, to check against the table in the design.
///
/// The eight answers are, in order: on Crit Alarm Cloud holding nothing,
/// Hosted, Pro, both. Then the same four on a server of the user's own.
// dart format off
const Map<AppFeature, List<FeatureDecision>> _truth = {
  //                                   cloud           own server
  //                                   -   H   P   HP  -   H   P   HP
  AppFeature.unlimitedCriticalTopics: [_h, _o, _h, _o, _o, _o, _o, _o],
  AppFeature.longHistory:             [_h, _o, _h, _o, _o, _o, _o, _o],
  AppFeature.storageRules:            [_h, _o, _h, _o, _o, _o, _o, _o],
  AppFeature.appIcons:                [_h, _o, _h, _o, _o, _o, _o, _o],
  AppFeature.widgets:                 [_h, _o, _h, _o, _o, _o, _o, _o],
  AppFeature.ownSounds:               [_p, _p, _o, _o, _p, _p, _o, _o],
  AppFeature.alarmScreenStyles:       [_p, _p, _o, _o, _p, _p, _o, _o],
  AppFeature.wakeUpChallenges:        [_p, _p, _o, _o, _p, _p, _o, _o],
  AppFeature.weeklyCheck:             [_p, _p, _o, _o, _p, _p, _o, _o],
};
// dart format on

const List<Set<Holding>> _held = [
  {},
  {Holding.hosted},
  {Holding.pro},
  {Holding.hosted, Holding.pro},
];

void main() {
  group('featureTable', () {
    test('has a row for every feature', () {
      for (final feature in AppFeature.values) {
        expect(featureTable[feature], isNotNull, reason: feature.name);
      }
      expect(featureTable.length, AppFeature.values.length);
    });

    test('every row names at least one holding to unlock it', () {
      for (final entry in featureTable.entries) {
        expect(entry.value.unlockedBy, isNotEmpty, reason: entry.key.name);
      }
    });

    test('is the table in the design, row for row', () {
      const hostedOpenOnOwn = [
        AppFeature.unlimitedCriticalTopics,
        AppFeature.longHistory,
        AppFeature.storageRules,
        AppFeature.appIcons,
        // Hosted until the widgets move to Pro, which is this one row.
        AppFeature.widgets,
      ];
      const proEverywhere = [
        AppFeature.ownSounds,
        AppFeature.alarmScreenStyles,
        AppFeature.wakeUpChallenges,
        AppFeature.weeklyCheck,
      ];
      expect([...hostedOpenOnOwn, ...proEverywhere], AppFeature.values);
      for (final feature in hostedOpenOnOwn) {
        final rule = featureTable[feature]!;
        expect(rule.unlockedBy, {Holding.hosted}, reason: feature.name);
        expect(rule.onOwnServer, OwnServerRule.open, reason: feature.name);
      }
      for (final feature in proEverywhere) {
        final rule = featureTable[feature]!;
        expect(rule.unlockedBy, {Holding.pro}, reason: feature.name);
        expect(
          rule.onOwnServer,
          OwnServerRule.sameAsCloud,
          reason: feature.name,
        );
      }
    });
  });

  group('truth table', () {
    test('lists every feature with eight answers', () {
      expect(_truth.keys, AppFeature.values);
      for (final row in _truth.values) {
        expect(row, hasLength(8));
      }
    });

    for (final feature in AppFeature.values) {
      for (var column = 0; column < 8; column++) {
        final held = _held[column % 4];
        final isOwnServer = column >= 4;
        final names = held.isEmpty
            ? 'nothing'
            : held.map((holding) => holding.name).join(' and ');
        final where = isOwnServer ? 'own server' : 'cloud';

        test('${feature.name}, holding $names, on $where', () {
          final holdings = Holdings([
            for (final holding in Holding.values)
              FakeHoldingSource(
                holding,
                held.contains(holding)
                    ? HoldingState.held
                    : HoldingState.notHeld,
              ),
          ]);
          final access = FeatureAccess(
            holdings: holdings,
            serverMode: isOwnServer ? ServerMode.selfhosted : ServerMode.hosted,
          );
          addTearDown(access.dispose);
          // Own server is `selfhosted` alone. The relay itself and a server
          // not known yet have plans, so they read the cloud columns.
          if (!isOwnServer) {
            for (final mode in [ServerMode.relay, null]) {
              final other = FeatureAccess(holdings: holdings, serverMode: mode);
              addTearDown(other.dispose);
              expect(
                other.decide(feature),
                _truth[feature]![column],
                reason: 'on $mode',
              );
            }
          }
          addTearDown(holdings.dispose);

          final expected = _truth[feature]![column];
          expect(access.decide(feature), expected);
          expect(access.can(feature), expected == _open);
        });
      }
    }
  });
}
