import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/first_topic_rules.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/widgets/first_topic_critical_card.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late CreateTopicCubit cubit;

  setUp(() {
    cubit = CreateTopicCubit(
      CreateTopicUsecase(InMemoryTopicRepository(MockApiClient(MockServer()))),
    );
  });

  tearDown(() => cubit.close());

  group('first topic detection', () {
    test('is true only for a ready list with no names', () {
      expect(isFirstTopicFor(existingNames: {}, isListReady: true), isTrue);
    });

    test('is false while the list has not loaded', () {
      expect(isFirstTopicFor(existingNames: {}, isListReady: false), isFalse);
      expect(cubit.state.isFirstTopic, isFalse);
    });

    test('is false with one or more names, ready or not', () {
      expect(
        isFirstTopicFor(existingNames: {'prod-db'}, isListReady: true),
        isFalse,
      );
      expect(
        isFirstTopicFor(existingNames: {'a', 'b'}, isListReady: false),
        isFalse,
      );
    });

    test('the state follows the list: loading, then empty, then a topic', () {
      cubit.existingNamesChanged(const [], isListReady: false);
      expect(cubit.state.isFirstTopic, isFalse);

      cubit.existingNamesChanged(const [], isListReady: true);
      expect(cubit.state.isFirstTopic, isTrue);

      cubit.existingNamesChanged(const ['prod-db'], isListReady: true);
      expect(cubit.state.isFirstTopic, isFalse);
    });

    test('names alone do not say the list is ready', () {
      cubit.existingNamesChanged(const <String>[]);
      expect(cubit.state.isFirstTopic, isFalse);
    });

    test('a later call that leaves readiness out keeps it', () {
      cubit
        ..existingNamesChanged(const <String>[], isListReady: true)
        ..existingNamesChanged(const ['x'])
        ..existingNamesChanged(const <String>[]);
      expect(cubit.state.isFirstTopic, isTrue);
    });
  });

  group('Critical delivery stays off', () {
    test('a chip tap does not turn it on', () {
      for (final template in ToolTemplate.values) {
        cubit.toolTemplateTapped(template);
        expect(cubit.state.isCritical, isFalse);
      }
    });

    test('feeding in the topic list does not turn it on', () {
      cubit.existingNamesChanged(const <String>[], isListReady: true);
      expect(cubit.state.isCritical, isFalse);
      cubit.existingNamesChanged(const ['prod-db'], isListReady: true);
      expect(cubit.state.isCritical, isFalse);
    });

    test('a plan reload does not turn it on', () async {
      SharedPreferences.setMockInitialValues({'device_id': 'dev_1'});
      final identity = DeviceIdentityStore(
        await SharedPreferences.getInstance(),
      );
      await identity.saveRegistration(
        deviceToken: 'dv_1',
        accountId: 'acc_1',
        tier: 'free',
        caps: AccountCaps.free,
      );
      final plan = PlanChanges();
      final withPlan = CreateTopicCubit(
        CreateTopicUsecase(
          InMemoryTopicRepository(MockApiClient(MockServer())),
        ),
        null,
        identity,
        null,
        const NoProOverride(),
        plan,
      );
      addTearDown(withPlan.close);
      await withPlan.loadConnection();

      plan.setStoreSaysPro(value: true);
      await pumpEventQueue();

      expect(withPlan.state.isFreeTier, isFalse);
      expect(withPlan.state.isCritical, isFalse);
    });

    test('only criticalToggled changes it', () {
      expect(cubit.state.isCritical, isFalse);
      cubit.criticalToggled(isCritical: true);
      expect(cubit.state.isCritical, isTrue);
      cubit.toolTemplateTapped(ToolTemplate.cron);
      expect(cubit.state.isCritical, isTrue);
      cubit.criticalToggled(isCritical: false);
      expect(cubit.state.isCritical, isFalse);
    });
  });

  group('card tone', () {
    test('is calm while the switch is off and crit once it is on', () {
      expect(
        firstTopicCardTone(isCritical: false),
        AppHighlightTone.calm,
      );
      expect(firstTopicCardTone(isCritical: true), AppHighlightTone.crit);
    });
  });

  group('card copy', () {
    FirstTopicCardCopy copy(
      RingClaim claim, {
      required bool on,
      bool plan = false,
    }) => firstTopicCardCopy(claim: claim, isCritical: on, hasPlanLine: plan);

    test('alarm, off: asks, keeps the subtitle and says what off costs', () {
      final c = copy(RingClaim.alarm, on: false);
      expect(c.titleKey, LocaleKeys.create_topic_first_topic_critical_title);
      expect(c.subtitleKey, LocaleKeys.create_topic_critical_toggle_subtitle);
      expect(
        c.offLineKey,
        LocaleKeys.create_topic_first_topic_critical_off_line,
      );
    });

    test(
      'alarm, on: states it, adds only Do Not Disturb, drops the off line',
      () {
        final c = copy(RingClaim.alarm, on: true);
        expect(
          c.titleKey,
          LocaleKeys.create_topic_first_topic_critical_title_on,
        );
        expect(
          c.subtitleKey,
          LocaleKeys.create_topic_first_topic_critical_subtitle_on,
        );
        expect(c.offLineKey, isNull);
      },
    );

    test('time-sensitive, off: its own words', () {
      final c = copy(RingClaim.timeSensitive, on: false);
      expect(
        c.titleKey,
        LocaleKeys.create_topic_first_topic_critical_title_time_sensitive,
      );
      expect(
        c.subtitleKey,
        LocaleKeys.create_topic_critical_toggle_subtitle_time_sensitive,
      );
      expect(c.offLineKey, isNotNull);
    });

    test('time-sensitive, on: states it and never promises silent mode', () {
      final c = copy(RingClaim.timeSensitive, on: true);
      expect(
        c.titleKey,
        LocaleKeys.create_topic_first_topic_critical_title_time_sensitive_on,
      );
      expect(
        c.subtitleKey,
        LocaleKeys.create_topic_first_topic_critical_subtitle_time_sensitive_on,
      );
      expect(c.offLineKey, isNull);
    });

    test('the alarm words are never used for a time-sensitive phone', () {
      const alarmKeys = {
        LocaleKeys.create_topic_first_topic_critical_title,
        LocaleKeys.create_topic_first_topic_critical_title_on,
        LocaleKeys.create_topic_critical_toggle_subtitle,
        LocaleKeys.create_topic_first_topic_critical_subtitle_on,
      };
      for (final on in [false, true]) {
        final c = copy(RingClaim.timeSensitive, on: on);
        expect(alarmKeys.contains(c.titleKey), isFalse);
        expect(alarmKeys.contains(c.subtitleKey), isFalse);
      }
    });

    test('no subtitle repeats its title', () {
      for (final claim in RingClaim.values) {
        for (final on in [false, true]) {
          final c = copy(claim, on: on);
          expect(c.subtitleKey, isNot(c.titleKey));
        }
      }
    });

    test('the plan line follows the switch on the free plan only', () {
      for (final claim in RingClaim.values) {
        expect(
          copy(claim, on: false, plan: true).planLineKey,
          LocaleKeys.create_topic_first_topic_critical_free_plan_line_off,
        );
        expect(
          copy(claim, on: true, plan: true).planLineKey,
          LocaleKeys.create_topic_first_topic_critical_free_plan_line_on,
        );
        expect(copy(claim, on: false).planLineKey, isNull);
        expect(copy(claim, on: true).planLineKey, isNull);
      }
    });
  });
}
