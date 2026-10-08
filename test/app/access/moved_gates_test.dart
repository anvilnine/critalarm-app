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

    test('lock on Crit Alarm Cloud without Hosted', () {
      expect(isLocked(access()), isTrue);
      expect(isLocked(access(held: {Holding.pro})), isTrue);
    });

    test('open with Hosted and on a server of the user own', () {
      expect(isLocked(access(held: {Holding.hosted})), isFalse);
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

    test('is on without Hosted on Crit Alarm Cloud', () {
      expect(isLocked(access()), isTrue);
      expect(isLocked(access(held: {Holding.pro})), isTrue);
    });

    test('is off with Hosted and on a server of the user own', () {
      expect(isLocked(access(held: {Holding.hosted})), isFalse);
      expect(isLocked(access(serverMode: ServerMode.selfhosted)), isFalse);
    });

    test('with the server unknown it follows what is held', () {
      // Before, the lock was off here whatever was held.
      expect(isLocked(access(serverMode: null)), isTrue);
      expect(
        isLocked(access(held: {Holding.hosted}, serverMode: null)),
        isFalse,
      );
    });
  });

  group('the Home widgets card', () {
    HomeWidgetsPlan planFor(TestAccess access) => homeWidgetsPlanFor(
      access.features.decide(AppFeature.widgets),
      isOwnServer: access.features.isOwnServer,
    );

    test('needs a plan on Crit Alarm Cloud without one', () {
      expect(planFor(access()), HomeWidgetsPlan.needsHosted);
    });

    test('is on the plan when the plan is held', () {
      expect(planFor(access(held: {Holding.hosted})), HomeWidgetsPlan.hosted);
    });

    test("says there are no plans on a server of the user's own", () {
      expect(
        planFor(access(serverMode: ServerMode.selfhosted)),
        HomeWidgetsPlan.selfHosted,
      );
      expect(
        planFor(
          access(held: {Holding.hosted}, serverMode: ServerMode.selfhosted),
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
        HomeWidgetsPlan.needsHosted,
      );
    });
  });

  group('the weekly check row', () {
    bool isOpen(TestAccess access) =>
        access.features.decide(AppFeature.weeklyCheck) is FeatureOpen;

    test('needs Pro, on Crit Alarm Cloud and on an own server', () {
      for (final mode in ServerMode.values) {
        expect(isOpen(access(serverMode: mode)), isFalse, reason: '$mode');
        expect(
          isOpen(access(held: {Holding.hosted}, serverMode: mode)),
          isFalse,
          reason: '$mode',
        );
        expect(
          isOpen(access(held: {Holding.pro}, serverMode: mode)),
          isTrue,
          reason: '$mode',
        );
      }
    });

    test('stays locked while a Pro purchase is being confirmed', () {
      final confirming = access()..pro.set(HoldingState.pending);
      expect(confirming.features.can(AppFeature.weeklyCheck), isTrue);
      expect(isOpen(confirming), isFalse);
    });
  });

  group('the Storage rows in search', () {
    bool findsStorage(TestAccess access) => SettingsSearchIndex.forBuild(
      includeDevOnly: false,
      showsStorage: access.features.can(AppFeature.storageRules),
    ).any((destination) => destination.needsStorageSection);

    test('are found with Hosted and on a server of the user own', () {
      expect(findsStorage(access(held: {Holding.hosted})), isTrue);
      expect(findsStorage(access(serverMode: ServerMode.selfhosted)), isTrue);
    });

    test('are left out on Crit Alarm Cloud without Hosted', () {
      expect(findsStorage(access()), isFalse);
      expect(findsStorage(access(held: {Holding.pro})), isFalse);
    });
  });
}
