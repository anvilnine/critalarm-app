import 'package:critalarm/core/account/plan_changes.dart';
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
}
