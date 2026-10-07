import 'dart:async';

import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/push/relay_confirmation_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The relay, as far as the registry can tell. Throws [error] when set.
class _Relay implements ApiClient {
  int calls = 0;
  Exception? error;

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
    String? accountJoinToken,
  }) async {
    calls++;
    if (error != null) throw error!;
    return const DeviceRegistrationResponse(
      accountId: 'acc_1',
      caps: AccountCaps(),
      deviceToken: 'dv_1',
    );
  }

  @override
  Future<DeviceRegistrationResponse> refreshDevice(
    DeviceRegistration registration,
    String deviceToken, {
    Uri? relayUri,
  }) async {
    calls++;
    if (error != null) throw error!;
    return const DeviceRegistrationResponse(
      accountId: 'acc_1',
      caps: AccountCaps(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Tokens implements PushTokenProvider {
  String token = 'fcm-token-1';
  final _rotations = StreamController<String>.broadcast();

  @override
  PushTokenKind get kind => PushTokenKind.fcm;

  @override
  Future<String> getToken() async => token;

  @override
  Stream<String> get tokenRefreshes => _rotations.stream;

  void rotate(String next) {
    token = next;
    _rotations.add(next);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _Relay relay;
  late _Tokens tokens;
  late DateTime now;
  late DeviceTokenRegistry registry;

  void advance(Duration by) => now = now.add(by);

  DeviceTokenRegistry build() => DeviceTokenRegistry(
    prefs: prefs,
    register: RegisterDeviceUsecase(
      relay,
      DeviceIdentityStore(prefs),
      tokens,
      platform: () => 'android',
    ),
    tokens: tokens,
    appVersion: '0.1.0',
    now: () => now,
    wait: (_) async {},
    log: (_) {},
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    relay = _Relay();
    tokens = _Tokens();
    now = DateTime.utc(2026, 10, 7, 8);
    registry = build();
  });

  tearDown(() => registry.stop());

  test(
    'the first launch registers and records the relay accepted it',
    () async {
      await registry.start();
      expect(relay.calls, 1);
      expect(registry.confirmations.confirmedAt, now);
      expect(registry.confirmations.lastOutcome, RelayAttemptOutcome.accepted);
    },
  );

  test('a launch inside 24 hours sends nothing', () async {
    await registry.start();
    advance(const Duration(hours: 23, minutes: 59));
    await build().start();
    expect(relay.calls, 1);
  });

  test('a launch after 24 hours sends the unchanged token again', () async {
    await registry.start();
    advance(const Duration(hours: 24));
    await build().start();
    expect(relay.calls, 2);
    expect(registry.confirmations.confirmedAt, now);
  });

  test(
    'an old install with a stored token confirms on its first launch',
    () async {
      await prefs.setString(DeviceTokenRegistry.lastTokenKey, 'fcm-token-1');
      await prefs.setString(DeviceTokenRegistry.lastVersionKey, '0.1.0');
      await prefs.setString(DeviceTokenRegistry.lastKindKey, 'fcm');
      await registry.start();
      expect(relay.calls, 1);
      expect(registry.confirmations.confirmedAt, now);
    },
  );

  test('resumes inside 24 hours make no call and read no token', () async {
    await registry.start();
    for (var i = 0; i < 5; i++) {
      advance(const Duration(hours: 4));
      await registry.onResumed();
    }
    // 20 hours on.
    expect(relay.calls, 1);
  });

  test(
    'a resume at 24 hours confirms once, and the next resume does not',
    () async {
      await registry.start();
      advance(const Duration(hours: 24));
      await registry.onResumed();
      expect(relay.calls, 2);
      advance(const Duration(minutes: 5));
      await registry.onResumed();
      expect(relay.calls, 2);
    },
  );

  test('a token change goes out at once, inside the 24 hours', () async {
    await registry.start();
    advance(const Duration(hours: 1));
    tokens.rotate('fcm-token-2');
    await Future<void>.delayed(Duration.zero);
    expect(relay.calls, 2);
    expect(registry.confirmations.confirmedAt, now);
  });

  test('a change on resume goes out at once too', () async {
    await registry.start();
    advance(const Duration(hours: 1));
    tokens.token = 'fcm-token-2';
    expect(await registry.syncToken(null), isTrue);
    expect(relay.calls, 2);
  });

  test('a token change restarts the 24 hours', () async {
    await registry.start();
    advance(const Duration(hours: 20));
    await registry.syncToken('fcm-token-2');
    advance(const Duration(hours: 20));
    await registry.onResumed();
    expect(relay.calls, 2, reason: 'only 20 hours since the change');
    advance(const Duration(hours: 4));
    await registry.onResumed();
    expect(relay.calls, 3);
  });

  test('a clock set back counts as due', () async {
    await registry.start();
    now = now.subtract(const Duration(days: 2));
    await registry.onResumed();
    expect(relay.calls, 2);
  });

  test(
    'confirmNow sends inside the 24 hours and says whether it was accepted',
    () async {
      await registry.start();
      advance(const Duration(minutes: 1));
      expect(await registry.confirmNow(), isTrue);
      expect(relay.calls, 2);

      relay.error = const ApiException(statusCode: 401, message: 'no');
      expect(await registry.confirmNow(), isFalse);
    },
  );

  group('how a failed call is recorded', () {
    test('a 4xx is a refusal and keeps the last good time', () async {
      await registry.start();
      final good = now;
      advance(const Duration(hours: 24));
      relay.error = const ApiException(statusCode: 401, message: 'no');
      await registry.onResumed();
      expect(registry.confirmations.lastOutcome, RelayAttemptOutcome.refused);
      expect(registry.confirmations.confirmedAt, good);
      expect(registry.confirmations.lastAttemptAt, now);
    });

    test('a 429 on the device cap is a refusal', () async {
      relay.error = const ApiException(
        statusCode: 429,
        message: 'cap',
        cap: 'devices',
      );
      await registry.start();
      expect(registry.confirmations.lastOutcome, RelayAttemptOutcome.refused);
    });

    test('a network error is a failure, not a refusal', () async {
      relay.error = Exception('relay unreachable');
      await registry.start();
      expect(registry.confirmations.lastOutcome, RelayAttemptOutcome.failed);
      expect(registry.confirmations.confirmedAt, isNull);
    });

    test('a failed confirmation is retried on the next resume', () async {
      await registry.start();
      advance(const Duration(hours: 24));
      relay.error = const ApiException(statusCode: 403, message: 'no');
      await registry.onResumed();
      expect(registry.launchCallsPending, isTrue);
      expect(relay.calls, 2);

      relay.error = null;
      advance(const Duration(minutes: 1));
      await registry.onResumed();
      expect(relay.calls, 3);
      expect(registry.launchCallsPending, isFalse);
      expect(registry.confirmations.lastOutcome, RelayAttemptOutcome.accepted);
    });
  });
}
