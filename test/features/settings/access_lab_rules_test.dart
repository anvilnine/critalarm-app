import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/access/access_override.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/features/settings/presentation/access_lab_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every path the router has, written out in full.
Set<String> _paths(List<RouteBase> routes, [String parent = '']) {
  final found = <String>{};
  for (final route in routes) {
    var here = parent;
    if (route is GoRoute) {
      here = route.path.startsWith('/')
          ? route.path
          : '${parent == '/' ? '' : parent}/${route.path}';
      found.add(here);
    }
    found.addAll(_paths(route.routes, here));
  }
  return found;
}

void main() {
  group('jump targets', () {
    test('every feature has one, or is listed as not built yet', () {
      for (final feature in AppFeature.values) {
        final hasJump = accessLabJumps.containsKey(feature);
        final isNotBuilt = accessLabNotBuilt.contains(feature);
        expect(
          hasJump != isNotBuilt,
          isTrue,
          reason:
              '${feature.name} needs one line in accessLabJumps, or in '
              'accessLabNotBuilt until its screen exists, and never both',
        );
      }
    });

    test('name no feature that is gone from the table', () {
      for (final feature in [...accessLabJumps.keys, ...accessLabNotBuilt]) {
        expect(featureTable.containsKey(feature), isTrue, reason: feature.name);
      }
    });

    test('the features that have a screen today', () {
      expect(accessLabJumps.keys.toSet(), {
        AppFeature.unlimitedCriticalTopics,
        AppFeature.longHistory,
        AppFeature.storageRules,
        AppFeature.appIcons,
        AppFeature.widgets,
        AppFeature.ownSounds,
        AppFeature.weeklyCheck,
      });
      expect(accessLabNotBuilt, {
        AppFeature.alarmScreenStyles,
        AppFeature.wakeUpChallenges,
      });
    });

    test('say where they go', () {
      expect(accessLabJumpText(AppFeature.ownSounds), 'Goes to Sound picker');
      expect(accessLabJumpText(AppFeature.wakeUpChallenges), 'Not built yet');
    });

    group('against the router', () {
      late Set<String> paths;

      setUp(() async {
        TestWidgetsFlutterBinding.ensureInitialized();
        SharedPreferences.setMockInitialValues({});
        await getIt.reset();
        await configureDependencies(useMockApi: true);
        paths = _paths(buildRouter().configuration.routes);
      });

      tearDown(getIt.reset);

      test('each page is a route the app has', () {
        expect(accessLabPages.map((page) => page.label), ['Personalize']);
        for (final page in accessLabPages) {
          expect(paths, contains(page.location), reason: page.label);
        }
      });

      test('each one is a route the app has', () {
        for (final entry in accessLabJumps.entries) {
          expect(
            paths,
            contains(entry.value.location),
            reason: entry.key.name,
          );
        }
      });

      test('a store build has Developer options and no lab route', () {
        expect(buildSkipsPaywall, isFalse);
        expect(paths, contains('/settings/developer'));
        expect(paths, isNot(contains('/settings/developer/access')));
      });
    });
  });

  group('row text', () {
    test('a feature and a holding are named from their enum names', () {
      expect(
        accessLabFeatureName(AppFeature.unlimitedCriticalTopics),
        'Unlimited critical topics',
      );
      expect(accessLabFeatureName(AppFeature.widgets), 'Widgets');
      expect(accessLabHoldingName(Holding.hosted), 'Hosted');
      expect(accessLabHoldingName(Holding.pro), 'Pro');
    });

    test('a decision reads as open, locked, confirming or unread', () {
      expect(accessLabDecisionText(const FeatureDecision.open()), 'Open');
      expect(
        accessLabDecisionText(const FeatureDecision.locked(Holding.hosted)),
        'Locked, sells Hosted',
      );
      expect(
        accessLabDecisionText(const FeatureDecision.confirming(Holding.pro)),
        'Open, confirming Pro',
      );
      expect(
        accessLabDecisionText(const FeatureDecision.unread(Holding.pro)),
        'Open, Pro unread',
      );
    });

    test('the rule line is read from the table row', () {
      expect(
        accessLabRuleText(
          const FeatureRule(
            unlockedBy: {Holding.hosted},
            onOwnServer: OwnServerRule.open,
          ),
        ),
        'Needs Hosted, or own server',
      );
      expect(
        accessLabRuleText(
          const FeatureRule(
            unlockedBy: {Holding.pro, Holding.hosted},
            onOwnServer: OwnServerRule.sameAsCloud,
          ),
        ),
        'Needs Pro or Hosted, own server too',
      );
      expect(accessLabRuleText(null), 'No row: open to all');
    });

    test('every state and choice has words', () {
      for (final state in HoldingState.values) {
        expect(accessLabStateText(state), isNotEmpty);
      }
      expect(
        {
          for (final state in [null, ...HoldingState.values])
            accessLabStateChoiceText(state),
        },
        hasLength(HoldingState.values.length + 1),
      );
      expect(
        ServerModeChoice.values.map(accessLabServerChoiceText).toSet(),
        hasLength(ServerModeChoice.values.length),
      );
      expect(accessLabServerModeText(ServerMode.selfhosted), 'selfhosted');
      expect(accessLabServerModeText(null), 'not known (no session)');
    });

    test('the holding line says what the app sees and what is real', () {
      expect(
        accessLabHoldingLine(
          seen: HoldingState.held,
          real: HoldingState.notHeld,
        ),
        'App sees held. Real source says not held.',
      );
    });
  });

  group('the line at the top of Developer options', () {
    test('is absent while nothing is forced', () {
      expect(
        accessLabForcedLine(
          forced: const {},
          serverMode: ServerModeChoice.real,
        ),
        isNull,
      );
      expect(
        accessLabForcedLine(
          forced: const {Holding.hosted: null, Holding.pro: null},
          serverMode: ServerModeChoice.real,
        ),
        isNull,
      );
    });

    test('names each forced holding and the server', () {
      expect(
        accessLabForcedLine(
          forced: const {
            Holding.hosted: HoldingState.notHeld,
            Holding.pro: HoldingState.pending,
          },
          serverMode: ServerModeChoice.ownServer,
        ),
        'Forced, not real: Hosted not held, Pro purchase confirming, '
        'server own',
      );
      expect(
        accessLabForcedLine(
          forced: const {Holding.pro: HoldingState.held},
          serverMode: ServerModeChoice.real,
        ),
        'Forced, not real: Pro held',
      );
      expect(
        accessLabForcedLine(
          forced: const {},
          serverMode: ServerModeChoice.unknown,
        ),
        'Forced, not real: server unknown',
      );
    });
  });
}
