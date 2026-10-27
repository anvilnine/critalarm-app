import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_rule.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/features/search/domain/settings_search_index.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/access/access_fakes.dart';

/// One test per gate that moved onto feature access and had no test of its
/// own. Each checks the rule the way its call site reads it.
void main() {
  TestAccess access({
    Set<Holding> held = const {},
    ServerMode? serverMode = ServerMode.hosted,
  }) {
    final built = TestAccess(held: held, serverMode: serverMode);
    addTearDown(built.dispose);
    return built;
  }

  group('the critical topic cap', () {
    const free = DeviceIdentity(
      deviceId: 'd1',
      accountId: 'acc_1',
      caps: AccountCaps.free,
    );

    int? capFor(TestAccess access) => const AccountAccess(free).freeCriticalCap(
      isUnlimited: access.features.can(AppFeature.unlimitedCriticalTopics),
    );

    test('is the registered number on Crit Alarm Cloud without Hosted', () {
      expect(capFor(access()), AccountCaps.free.criticalTopics);
      expect(capFor(access(held: {Holding.pro})), 2);
    });

    test('is not stated with Hosted, held or still being confirmed', () {
      expect(capFor(access(held: {Holding.hosted})), isNull);
      final confirming = access()..hosted.set(HoldingState.pending);
      expect(capFor(confirming), isNull);
    });

    test("is not stated on a server of the user's own", () {
      expect(capFor(access(serverMode: ServerMode.selfhosted)), isNull);
    });

    test('falls back to 2 when the registration sent no caps', () {
      expect(
        const AccountAccess(null).freeCriticalCap(isUnlimited: false),
        2,
      );
    });
  });

  group('the app icons, picker and guard alike', () {
    bool isLocked(TestAccess access) => AppIconRule.isLocked(
      AppIcon.crowned,
      unlocked: access.features.can(AppFeature.appIcons),
    );

    test('lock on Crit Alarm Cloud with neither Hosted nor Pro', () {
      expect(isLocked(access()), isTrue);
    });

    test('open with Hosted, with Pro, and on a server of the user own', () {
      expect(isLocked(access(held: {Holding.hosted})), isFalse);
      expect(isLocked(access(held: {Holding.pro})), isFalse);
      expect(isLocked(access(serverMode: ServerMode.selfhosted)), isFalse);
    });

    test('with the server unknown they follow what is held', () {
      // Before, the picker locked every icon here even with Hosted held.
      expect(isLocked(access(serverMode: null)), isTrue);
      expect(
        isLocked(access(held: {Holding.hosted}, serverMode: null)),
        isFalse,
      );
    });

    test('the standard icon is never locked', () {
      expect(
        AppIconRule.isLocked(
          AppIcon.standard,
          unlocked: access().features.can(AppFeature.appIcons),
        ),
        isFalse,
      );
    });
  });

  group('the widget lock', () {
    bool isLocked(TestAccess access) =>
        !access.features.can(AppFeature.widgets);

    test('is on without Pro, on Crit Alarm Cloud and on an own server', () {
      for (final mode in ServerMode.values) {
        expect(isLocked(access(serverMode: mode)), isTrue, reason: '$mode');
        expect(
          isLocked(access(held: {Holding.hosted}, serverMode: mode)),
          isTrue,
          reason: 'Hosted does not unlock widgets, $mode',
        );
      }
    });

    test('is off with Pro, on Crit Alarm Cloud and on an own server', () {
      for (final mode in ServerMode.values) {
        expect(
          isLocked(access(held: {Holding.pro}, serverMode: mode)),
          isFalse,
          reason: '$mode',
        );
      }
    });

    test('with the server unknown it follows what is held', () {
      expect(isLocked(access(serverMode: null)), isTrue);
      expect(isLocked(access(held: {Holding.pro}, serverMode: null)), isFalse);
    });
  });

  group('the Home widgets card', () {
    HomeWidgetsPlan planFor(TestAccess access) => homeWidgetsPlanFor(
      access.features.decide(AppFeature.widgets),
      isOwnServer: access.features.isOwnServer,
    );

    test('needs Pro on Crit Alarm Cloud without it, even with Hosted', () {
      expect(planFor(access()), HomeWidgetsPlan.needsPro);
      expect(
        planFor(access(held: {Holding.hosted})),
        HomeWidgetsPlan.needsPro,
      );
    });

    test('needs Pro on a server of the user own without it', () {
      expect(
        planFor(access(serverMode: ServerMode.selfhosted)),
        HomeWidgetsPlan.needsPro,
      );
    });

    test('is on the plan when Pro is held', () {
      expect(planFor(access(held: {Holding.pro})), HomeWidgetsPlan.pro);
    });

    test('is open on a server of the user own with Pro', () {
      expect(
        planFor(
          access(held: {Holding.pro}, serverMode: ServerMode.selfhosted),
        ),
        HomeWidgetsPlan.selfHosted,
      );
    });

    test('a locked decision wins over the server', () {
      expect(
        homeWidgetsPlanFor(
          const FeatureDecision.locked(Holding.pro),
          isOwnServer: true,
        ),
        HomeWidgetsPlan.needsPro,
      );
    });
  });

  group('the weekly check row', () {
    FeatureDecision decide(TestAccess access) =>
        access.features.decide(AppFeature.weeklyCheck);
    const sellsHosted = FeatureDecision.locked(Holding.hosted);

    test('needs Hosted on Crit Alarm Cloud and on the relay itself, and Pro '
        'changes nothing', () {
      for (final mode in [ServerMode.hosted, ServerMode.relay]) {
        expect(decide(access(serverMode: mode)), sellsHosted, reason: '$mode');
        expect(
          decide(access(held: {Holding.pro}, serverMode: mode)),
          sellsHosted,
          reason: '$mode',
        );
        expect(
          decide(access(held: {Holding.hosted}, serverMode: mode)),
          const FeatureDecision.open(),
          reason: '$mode',
        );
        expect(
          decide(access(held: {Holding.hosted, Holding.pro}, serverMode: mode)),
          const FeatureDecision.open(),
          reason: '$mode',
        );
      }
    });

    test('is not offered on a server of the user own, whatever is held', () {
      for (final held in <Set<Holding>>[
        {},
        {Holding.pro},
        {Holding.hosted},
        {Holding.hosted, Holding.pro},
      ]) {
        expect(
          decide(access(held: held, serverMode: ServerMode.selfhosted)),
          const FeatureDecision.notOffered(),
          reason: '$held',
        );
      }
    });

    test('stays locked while a Hosted purchase is being confirmed', () {
      final confirming = access()..hosted.set(HoldingState.pending);
      expect(confirming.features.can(AppFeature.weeklyCheck), isTrue);
      expect(decide(confirming), isNot(const FeatureDecision.open()));
    });
  });

  group('the app icons', () {
    test('are open with Hosted alone, with Pro alone, and on a server of '
        'the user own', () {
      expect(access().features.can(AppFeature.appIcons), isFalse);
      expect(
        access(held: {Holding.hosted}).features.can(AppFeature.appIcons),
        isTrue,
      );
      expect(
        access(held: {Holding.pro}).features.can(AppFeature.appIcons),
        isTrue,
      );
      expect(
        access(
          serverMode: ServerMode.selfhosted,
        ).features.can(AppFeature.appIcons),
        isTrue,
      );
    });
  });

  group('the Storage rows in search', () {
    test('are found by everyone: nothing held on Crit Alarm Cloud '
        'included', () {
      final ids = SettingsSearchIndex.forBuild(
        includeDevOnly: false,
      ).map((destination) => destination.id);
      expect(
        ids,
        containsAll(['storage-delete-after', 'storage-keep-critical']),
      );
    });
  });
}
