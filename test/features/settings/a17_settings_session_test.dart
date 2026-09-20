import 'dart:convert';

import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/server_settings_screen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SharedPrefsApiSessionStore sessions;
  late DeviceIdentityStore identity;
  late HttpApiClient api;
  late List<http.Request> requests;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    sessions = SharedPrefsApiSessionStore(prefs);
    identity = DeviceIdentityStore(prefs);
    requests = [];
    api = HttpApiClient(
      MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/info')) {
          return http.Response(
            jsonEncode({
              'version': '0.1.0',
              'base_url': 'https://second.example',
              'relay_url': 'https://second-relay.example',
              'mode': 'selfhosted',
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      }),
      sessions,
    );
  });

  SettingsCubit cubit() => SettingsCubit(
    apiSessions: sessions,
    identityStore: identity,
    getServerInfo: GetServerInfoUsecase(InMemoryServerRepository(api)),
    establishSession: EstablishApiSessionUsecase(
      sessions,
      RegisterDeviceUsecase(api, identity, _Tokens()),
      identity,
    ),
    saveConnectionUsecase: SaveConnectionUsecase(
      SharedPrefsConnectionRepository(prefs),
    ),
    clearConnectionUsecase: ClearConnectionUsecase(
      SharedPrefsConnectionRepository(prefs),
    ),
  );

  Future<void> connectFirstServer() async {
    await sessions.write(
      ApiSession(
        baseUri: Uri.parse('https://first.example'),
        relayUri: Uri.parse('https://first-relay.example'),
        mode: ServerMode.hosted,
        managementCredential: 'dv_first',
      ),
    );
  }

  test('saving a new server URL points the next request at it', () async {
    await connectFirstServer();
    final settings = cubit();

    await settings.saveConnection(
      serverUrl: 'https://second.example',
      adminToken: 'ad_second',
    );

    final session = (await sessions.read())!;
    expect(session.baseUri.toString(), 'https://second.example');
    expect(session.mode, ServerMode.selfhosted);
    expect(session.managementCredential, 'ad_second');
    expect(settings.state.serverMode, ServerMode.selfhosted);

    await api.getTopics();
    expect(requests.last.url.toString(), 'https://second.example/v1/topics');

    await settings.close();
  });

  test('disconnect clears the session and the device identity', () async {
    await connectFirstServer();
    final firstDeviceId = (await identity.readOrCreate()).deviceId;
    await identity.saveRegistration(
      deviceToken: 'dv_first',
      accountId: 'acc_first',
      tier: 'free',
    );
    final settings = cubit();

    await settings.disconnectServer();

    expect(await sessions.read(), isNull);
    expect(prefs.getString('device_id'), isNull);
    expect(prefs.getString('device_token'), isNull);

    // The next connect starts from a fresh identity.
    final next = await identity.readOrCreate();
    expect(next.deviceId, isNot(firstDeviceId));
    expect(next.deviceToken, isNull);

    await settings.close();
  });

  test('the mode label matches what the server reports', () {
    expect(
      serverModeLabelKey(ServerMode.selfhosted),
      LocaleKeys.settings_server_self_hosted,
    );
    expect(
      serverModeLabelKey(ServerMode.relay),
      LocaleKeys.settings_server_relay,
    );
    expect(
      serverModeLabelKey(ServerMode.hosted),
      LocaleKeys.settings_server_hosted,
    );
  });
}

class _Tokens implements PushTokenProvider {
  @override
  PushTokenKind get kind => PushTokenKind.apns;

  @override
  Future<String> getToken() async => 'apns_test';

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}
