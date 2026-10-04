import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/topics/data/prefs_first_topic_handoff.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/first_topic_rules.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:critalarm/features/topics/presentation/widgets/create_topic_face.dart';
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
    test('is an open choice while off and crit once it is on', () {
      expect(
        firstTopicCardTone(isCritical: false),
        AppHighlightTone.choice,
      );
      expect(firstTopicCardTone(isCritical: true), AppHighlightTone.crit);
    });

    test('off is never the settled tone, which is for a row that is done', () {
      expect(
        firstTopicCardTone(isCritical: false),
        isNot(AppHighlightTone.calm),
      );
    });
  });

  group('card copy', () {
    FirstTopicCardCopy copy(
      RingClaim claim, {
      required bool on,
      bool plan = false,
    }) => firstTopicCardCopy(claim: claim, isCritical: on, hasPlanLine: plan);

    test('alarm, off: one title and what off costs, no subtitle', () {
      final c = copy(RingClaim.alarm, on: false);
      expect(c.titleKey, LocaleKeys.create_topic_first_topic_critical_title);
      expect(c.subtitleKey, isNull);
      expect(
        c.offLineKey,
        LocaleKeys.create_topic_first_topic_critical_off_line,
      );
      expect(c.lineKey, c.offLineKey);
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
        expect(c.lineKey, c.subtitleKey);
      },
    );

    test('time-sensitive, off: its own title and its own off line', () {
      final c = copy(RingClaim.timeSensitive, on: false);
      expect(
        c.titleKey,
        LocaleKeys.create_topic_first_topic_critical_title_time_sensitive,
      );
      expect(c.subtitleKey, isNull);
      expect(
        c.offLineKey,
        LocaleKeys.create_topic_first_topic_critical_off_line_time_sensitive,
      );
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
        LocaleKeys.create_topic_first_topic_critical_off_line,
        LocaleKeys.create_topic_critical_toggle_subtitle,
        LocaleKeys.create_topic_first_topic_critical_subtitle_on,
      };
      for (final on in [false, true]) {
        final c = copy(RingClaim.timeSensitive, on: on);
        expect(alarmKeys.contains(c.titleKey), isFalse);
        expect(alarmKeys.contains(c.subtitleKey), isFalse);
        expect(alarmKeys.contains(c.offLineKey), isFalse);
      }
    });

    test('every state shows exactly one line under its title', () {
      for (final claim in RingClaim.values) {
        for (final on in [false, true]) {
          final c = copy(claim, on: on);
          expect(c.lineKey, isNotNull);
          expect(c.lineKey, isNot(c.titleKey));
          // Never both: the card is a title and a line.
          expect(c.subtitleKey == null || c.offLineKey == null, isTrue);
        }
      }
    });

    test('the plan line shows on the free plan only', () {
      for (final claim in RingClaim.values) {
        for (final on in [false, true]) {
          expect(copy(claim, on: on, plan: true).planLineKey, isNotNull);
          expect(copy(claim, on: on).planLineKey, isNull);
        }
      }
    });

    test('off, the plan line says the slot is used once it is on', () {
      for (final claim in RingClaim.values) {
        expect(
          copy(claim, on: false, plan: true).planLineKey,
          LocaleKeys.create_topic_first_topic_critical_plan_line_off,
        );
        expect(
          copy(claim, on: true, plan: true).planLineKey,
          LocaleKeys.create_topic_first_topic_critical_plan_line,
        );
      }
    });
  });

  group('one-step create, as in setup', () {
    late SharedPreferences prefs;
    late PrefsFirstTopicHandoff handoff;
    late MockServer server;
    late CreateTopicCubit setup;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      handoff = PrefsFirstTopicHandoff(prefs);
      server = MockServer();
      setup =
          CreateTopicCubit(
              CreateTopicUsecase(
                InMemoryTopicRepository(MockApiClient(server)),
              ),
            )
            ..handoff = handoff
            ..holdsHandoff = true
            ..isOneStep = true;
      addTearDown(setup.close);
    });

    test('creates from the first step, with no token step between', () async {
      setup.nameChanged('setup-test');
      expect(setup.state.step, CreateTopicStep.topic);

      await setup.createTopic();

      expect(setup.state.status, CreateTopicStatus.success);
      expect(setup.state.step, CreateTopicStep.topic);
      expect(setup.state.createdTopic!.name, 'setup-test');
    });

    test('hands the token on to the next steps, in memory', () async {
      setup.nameChanged('setup-test');
      await setup.createTopic();

      final held = handoff.entry!;
      expect(held.topicName, 'setup-test');
      expect(held.token, setup.state.createdToken);
      for (final key in prefs.getKeys()) {
        expect(prefs.get(key).toString().contains(held.token), isFalse);
      }
    });

    test(
      'Critical delivery is still off unless the user turned it on',
      () async {
        setup.nameChanged('setup-test');
        await setup.createTopic();
        expect(setup.state.createdTopic!.critical, isFalse);
      },
    );

    test('the user turning it on is what makes the topic critical', () async {
      setup
        ..nameChanged('setup-test')
        ..criticalToggled(isCritical: true);
      await setup.createTopic();
      expect(setup.state.createdTopic!.critical, isTrue);
    });

    test('names the token after the picked tool', () async {
      setup.toolTemplateTapped(ToolTemplate.uptimeKuma);
      await setup.createTopic();
      expect(setup.state.createdTopic!.tokenName, 'Uptime Kuma');
    });

    test('leaves the name to the server when no tool is picked', () async {
      final plain = CreateTopicCubit(
        CreateTopicUsecase(
          InMemoryTopicRepository(MockApiClient(MockServer())),
        ),
      )..nameChanged('same-name');
      addTearDown(plain.close);
      await plain.createTopic();

      setup.nameChanged('setup-test');
      await setup.createTopic();
      expect(
        setup.state.createdTopic!.tokenName,
        plain.state.createdTopic!.tokenName,
      );
    });

    test('an empty name stops on the first step and makes nothing', () async {
      await setup.createTopic();
      expect(setup.state.status, CreateTopicStatus.initial);
      expect(setup.state.errorMessage, isNotNull);
      expect(handoff.entry, isNull);
    });

    test('a name that is taken stops before the server is asked', () async {
      setup
        ..existingNamesChanged(const ['prod-db'], isListReady: true)
        ..nameChanged('prod-db');
      await setup.createTopic();
      expect(setup.state.status, CreateTopicStatus.initial);
      expect(setup.state.errorMessage, isNotNull);
      expect(handoff.entry, isNull);
    });

    test('a second tap while it is created makes no second topic', () async {
      setup.nameChanged('setup-test');
      await setup.createTopic();
      final first = setup.state.createdToken;
      await setup.createTopic();
      expect(setup.state.createdToken, first);
    });
  });

  group('the two-step screen, outside setup', () {
    test('keeps its token-name step and names nothing by itself', () async {
      cubit
        ..toolTemplateTapped(ToolTemplate.cron)
        ..nextStep();
      expect(cubit.state.step, CreateTopicStep.token);
      await cubit.createTopic();
      expect(cubit.state.status, CreateTopicStatus.success);
      expect(cubit.state.createdTopic!.tokenName, isNot('cron'));
    });

    test('a typed token name is used as typed', () async {
      cubit
        ..nameChanged('prod-db')
        ..nextStep()
        ..tokenNameChanged('CI server');
      await cubit.createTopic();
      expect(cubit.state.createdTopic!.tokenName, 'CI server');
    });
  });

  group('setupTokenName', () {
    test('is the tool name, or nothing for no tool and for other', () {
      expect(setupTokenName(ToolTemplate.healthchecks), 'Healthchecks');
      expect(setupTokenName(null), isNull);
      expect(setupTokenName(ToolTemplate.other), isNull);
    });
  });

  group('face', () {
    FaceState face({
      bool error = false,
      bool created = false,
      bool settled = false,
      bool critical = false,
    }) => createTopicFace(
      hasError: error,
      isCreated: created,
      hasSettled: settled,
      isCritical: critical,
    );

    test('asks while idle and is fierce once Critical is on', () {
      expect(face(), FaceState.curious);
      expect(face(critical: true), FaceState.determined);
    });

    test('an error wins over the switch', () {
      expect(face(error: true, critical: true), FaceState.worried);
    });

    test('is glad when the topic is made, then settles', () {
      expect(face(created: true), FaceState.success);
      expect(face(created: true, settled: true), FaceState.proud);
    });

    test('never waits: watching is for waits on something outside', () {
      for (final e in [false, true]) {
        for (final c in [false, true]) {
          for (final m in [false, true]) {
            expect(
              face(error: e, created: m, critical: c),
              isNot(FaceState.watching),
            );
          }
        }
      }
    });
  });
}
