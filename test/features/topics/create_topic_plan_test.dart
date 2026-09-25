import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sessions implements ApiSessionStore {
  _Sessions(this.mode);

  final ServerMode mode;

  @override
  Future<ApiSession?> read() async => ApiSession(
    baseUri: Uri.parse('https://example.test'),
    relayUri: Uri.parse('https://example.test'),
    mode: mode,
    managementCredential: 'x',
  );

  @override
  Future<void> write(ApiSession session) async {}

  @override
  Future<void> clear() async {}
}

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
    final cubit = CreateTopicCubit(
      createTopic,
      null,
      await freeAccount(),
      null,
      const NoProOverride(),
      PlanChanges(),
    )..sessionStore = _Sessions(ServerMode.selfhosted);
    addTearDown(cubit.close);

    await cubit.loadConnection();

    expect(cubit.state.isFreeTier, isFalse);
  });

  test('a free relay account is the free tier', () async {
    final cubit = CreateTopicCubit(
      createTopic,
      null,
      await freeAccount(),
      null,
      const NoProOverride(),
      PlanChanges(),
    )..sessionStore = _Sessions(ServerMode.hosted);
    addTearDown(cubit.close);

    await cubit.loadConnection();

    expect(cubit.state.isFreeTier, isTrue);
  });

  test('buying Pro drops the free tier on the open screen', () async {
    final plan = PlanChanges();
    final cubit = CreateTopicCubit(
      createTopic,
      null,
      await freeAccount(),
      null,
      const NoProOverride(),
      plan,
    );
    addTearDown(cubit.close);
    await cubit.loadConnection();
    expect(cubit.state.isFreeTier, isTrue);

    plan.setStoreSaysPro(value: true);
    await pumpEventQueue();

    expect(cubit.state.isFreeTier, isFalse);
  });
}
