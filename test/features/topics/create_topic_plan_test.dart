import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/access/store_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CreateTopicUsecase createTopic;

  setUp(() {
    createTopic = CreateTopicUsecase(
      InMemoryTopicRepository(MockApiClient(MockServer())),
    );
  });

  Future<DeviceIdentityStore> freeAccount() async {
    SharedPreferences.setMockInitialValues({'device_id': 'dev_1'});
    final identity = DeviceIdentityStore(await SharedPreferences.getInstance());
    await identity.saveRegistration(
      deviceToken: 'dv_1',
      accountId: 'acc_1',
      tier: 'free',
      caps: AccountCaps.free,
    );
    return identity;
  }

  test('a self-hosted server is never the free tier', () async {
    final identity = await freeAccount();
    final cubit = CreateTopicCubit(
      createTopic,
      null,
      identity,
      null,
      PlanChanges(),
      accessOver(identity, serverMode: ServerMode.selfhosted).features,
    );
    addTearDown(cubit.close);

    await cubit.loadConnection();

    expect(cubit.state.isFreeTier, isFalse);
  });

  test('a free relay account is the free tier', () async {
    final identity = await freeAccount();
    final cubit = CreateTopicCubit(
      createTopic,
      null,
      identity,
      null,
      PlanChanges(),
      accessOver(identity).features,
    );
    addTearDown(cubit.close);

    await cubit.loadConnection();

    expect(cubit.state.isFreeTier, isTrue);
  });

  test('buying Pro drops the free tier on the open screen', () async {
    final plan = PlanChanges();
    final identity = await freeAccount();
    final cubit = CreateTopicCubit(
      createTopic,
      null,
      identity,
      null,
      plan,
      accessOver(identity, planChanges: plan).features,
    );
    addTearDown(cubit.close);
    await cubit.loadConnection();
    expect(cubit.state.isFreeTier, isTrue);

    plan.setStoreSaysPro(value: true);
    await pumpEventQueue();

    expect(cubit.state.isFreeTier, isFalse);
  });

  group('the count card', () {
    test('is hidden at zero critical topics, on the first topic or after', () {
      const first = CreateTopicState(isListReady: true);
      expect(first.isFirstTopic, isTrue);
      expect(first.showsCriticalCountCard, isFalse);

      const later = CreateTopicState(
        isListReady: true,
        existingNames: {'a'},
      );
      expect(later.isFirstTopic, isFalse);
      expect(later.showsCriticalCountCard, isFalse);
    });

    test('shows at one and two critical topics', () {
      const names = {'a', 'b'};
      for (final used in [1, 2]) {
        final state = CreateTopicState(
          isListReady: true,
          existingNames: names,
          criticalUsed: used,
        );
        expect(state.isFirstTopic, isFalse);
        expect(state.showsCriticalCountCard, isTrue, reason: 'used $used');
      }
    });

    test('never shows off the free plan', () {
      const state = CreateTopicState(
        isListReady: true,
        existingNames: {'a'},
        isFreeTier: false,
        criticalUsed: 2,
      );
      expect(state.showsCriticalCountCard, isFalse);
    });
  });
}
