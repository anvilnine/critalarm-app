import 'dart:async';
import 'dart:convert';

import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/paywall/data/repositories/in_memory_subscription_repository.dart';
import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tokens implements PushTokenProvider {
  @override
  PushTokenKind get kind => PushTokenKind.apns;
  @override
  Future<String> getToken() async => 'apns_test';
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sdkChannel = MethodChannel('purchases_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late SharedPreferences prefs;
  late SharedPrefsApiSessionStore sessions;
  late DeviceIdentityStore identity;
  late HttpApiClient api;
  late RevenueCatService revenueCat;
  late RegisterDeviceUsecase register;
  late List<http.Request> requests;
  late List<MethodCall> sdkCalls;
  var mode = 'hosted';
  String? responseToken = 'dv_registered';
  Completer<void>? setupGate;
  final customerInfo = <String, Object?>{
    'entitlements': {'all': <String, Object?>{}, 'active': <String, Object?>{}},
    'allPurchaseDates': <String, Object?>{},
    'activeSubscriptions': <String>[],
    'allPurchasedProductIdentifiers': <String>[],
    'nonSubscriptionTransactions': <Object>[],
    'firstSeen': '2026-01-01T00:00:00Z',
    'originalAppUserId': 'acc_registered',
    'allExpirationDates': <String, Object?>{},
    'requestDate': '2026-01-01T00:00:00Z',
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    sessions = SharedPrefsApiSessionStore(prefs);
    identity = DeviceIdentityStore(prefs);
    requests = [];
    sdkCalls = [];
    mode = 'hosted';
    responseToken = 'dv_registered';
    setupGate = null;
    messenger.setMockMethodCallHandler(sdkChannel, (call) async {
      sdkCalls.add(call);
      if (call.method == 'setupPurchases') await setupGate?.future;
      if (call.method == 'logIn') {
        return {'customerInfo': customerInfo, 'created': false};
      }
      if (call.method == 'getCustomerInfo') return customerInfo;
      return null;
    });
    revenueCat = RevenueCatService();
    api = HttpApiClient(
      MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/info')) {
          return http.Response(
            jsonEncode({
              'version': '0.1.0',
              'base_url': 'https://canonical.example',
              'relay_url': 'https://relay.example/prefix',
              'mode': mode,
            }),
            200,
          );
        }
        expect(request.url.host, 'relay.example');
        expect(request.url.path, startsWith('/prefix/relay/v1/devices'));
        return http.Response(
          jsonEncode({
            if (request.method == 'POST' || responseToken == '')
              'device_token': responseToken,
            'account_id': 'acc_registered',
            'tier': request.method == 'PATCH' ? 'hosted' : 'free',
            'caps': {'devices': 5, 'critical_topics': 2, 'p4_daily': 1000},
          }),
          request.method == 'POST' ? 201 : 200,
        );
      }),
      sessions,
    );
    register = RegisterDeviceUsecase(
      api,
      identity,
      _Tokens(),
      platform: () => 'ios',
      identifyAccount: revenueCat.identifyAccount,
    );
  });
  tearDown(() async {
    await revenueCat.dispose();
    messenger.setMockMethodCallHandler(sdkChannel, null);
  });

  OnboardingConnectCubit connectCubit() => OnboardingConnectCubit(
    GetServerInfoUsecase(InMemoryServerRepository(api)),
    SaveConnectionUsecase(SharedPrefsConnectionRepository(prefs)),
    TriggerTestAlarmUsecase(InMemoryIncidentRepository(api)),
    establishSession: EstablishApiSessionUsecase(sessions, register, identity),
  );

  for (final serverMode in ['hosted', 'relay', 'selfhosted']) {
    test(
      '$serverMode probes typed URL and stores canonical URLs '
      'with correct credential',
      () async {
        mode = serverMode;
        final cubit = connectCubit()
          ..serverUrlChanged('https://typed.example/path')
          ..adminTokenChanged('ad_pasted');
        await cubit.connect();
        expect(cubit.state.isConnected, isTrue);
        expect(
          requests.first.url.toString(),
          'https://typed.example/path/v1/info',
        );
        expect(requests.first.headers['authorization'], isNull);
        final session = (await sessions.read())!;
        expect(session.baseUri.toString(), 'https://canonical.example');
        expect(session.relayUri.toString(), 'https://relay.example/prefix');
        expect(session.mode, ServerMode.fromWireValue(serverMode));
        expect(
          session.managementCredential,
          serverMode == 'selfhosted' ? 'ad_pasted' : 'dv_registered',
        );
        await cubit.close();
      },
    );
  }

  test('hosted connects without asking for an admin token', () async {
    final cubit = connectCubit()..serverUrlChanged('https://typed.example');
    await cubit.connect();
    expect(cubit.state.isConnected, isTrue);
    expect(cubit.state.requiresAdminToken, isFalse);
    expect(cubit.state.adminTokenError, isNull);
    await cubit.close();
  });

  for (final order in ['registration first', 'SDK first', 'during SDK setup']) {
    test('RevenueCat uses stored account_id: $order', () async {
      Future<void>? initialization;
      if (order == 'SDK first') await revenueCat.initialize(apiKey: 'test');
      if (order == 'during SDK setup') {
        setupGate = Completer<void>();
        initialization = revenueCat.initialize(apiKey: 'test');
        await Future<void>.delayed(Duration.zero);
      }
      await register(
        appVersion: '1.0',
        relayUri: Uri.parse('https://relay.example/prefix'),
      );
      expect((await identity.readOrCreate()).accountId, 'acc_registered');
      if (order == 'registration first') {
        await revenueCat.initialize(apiKey: 'test');
      }
      if (initialization != null) {
        setupGate!.complete();
        await initialization;
      }
      final logins = sdkCalls.where((c) => c.method == 'logIn');
      expect(logins, isNotEmpty);
      expect(logins.last.arguments, {'appUserID': 'acc_registered'});
    });
  }

  test(
    'empty response token is rejected and never overwrites a valid token',
    () async {
      await register(
        appVersion: '1.0',
        relayUri: Uri.parse('https://relay.example/prefix'),
      );
      responseToken = '';
      await expectLater(
        register(
          appVersion: '1.0',
          relayUri: Uri.parse('https://relay.example/prefix'),
        ),
        throwsStateError,
      );
      expect((await identity.readOrCreate()).deviceToken, 'dv_registered');
    },
  );

  test('empty first token is rejected without saving account', () async {
    responseToken = '';
    await expectLater(
      register(
        appVersion: '1.0',
        relayUri: Uri.parse('https://relay.example/prefix'),
      ),
      throwsStateError,
    );
    final saved = await identity.readOrCreate();
    expect(saved.deviceToken, isNull);
    expect(saved.accountId, isNull);
  });

  for (final action in ['purchase', 'restore']) {
    test(
      'successful $action invalidates CustomerInfo '
      'and re-registers to read tier',
      () async {
        final connection = connectCubit()
          ..serverUrlChanged('https://typed.example');
        await connection.connect();
        await revenueCat.initialize(apiKey: 'test');
        final repository = InMemorySubscriptionRepository();
        final paywall = PaywallCubit(
          identityStore: identity,
          purchasePackageUsecase: PurchasePackageUsecase(repository),
          restorePurchasesUsecase: RestorePurchasesUsecase(repository),
          refreshRegistration: () async {
            await revenueCat.invalidateCustomerInfoCache();
            await register(appVersion: '1.0');
          },
        );
        if (action == 'purchase') {
          const package = Package(
            'test',
            PackageType.annual,
            StoreProduct('test', 'Test', 'Test', 0, '', 'USD'),
            PresentedOfferingContext('test', null, null),
          );
          await paywall.upgradeToPro(package);
        } else {
          await paywall.restorePurchases();
        }
        expect(
          sdkCalls.where((c) => c.method == 'invalidateCustomerInfoCache'),
          hasLength(1),
        );
        expect(requests.where((r) => r.method == 'PATCH'), hasLength(1));
        expect(requests.last.headers['authorization'], 'Bearer dv_registered');
        expect((await identity.readOrCreate()).tier, 'hosted');
        await paywall.close();
        await connection.close();
        await repository.dispose();
      },
    );
  }
}
