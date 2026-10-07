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

/// A relay whose calls can be held open and let go in any order.
class _Relay implements ApiClient {
  final sent = <String>[];
  Exception? error;
  bool hold = false;
  final _held = <Completer<void>>[];

  Future<void> _call(String pushToken) async {
    sent.add(pushToken);
    if (error != null) throw error!;
    if (hold) {
      final gate = Completer<void>();
      _held.add(gate);
      await gate.future;
    }
  }

  /// Lets every held call go, newest first, until nothing is left in flight.
  Future<void> releaseNewestFirst() async {
    for (var i = 0; i < 20; i++) {
      await _pump();
      if (_held.isEmpty) return;
      _held.removeLast().complete();
    }
  }

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
    String? accountJoinToken,
  }) async {
    await _call(registration.pushToken);
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
    await _call(registration.pushToken);
    return const DeviceRegistrationResponse(
      accountId: 'acc_1',
      caps: AccountCaps(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Future<void> _pump() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Tokens implements PushTokenProvider {
  String token = 'token-1';
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

class _ThrowingStore extends RelayConfirmationStore {
  _ThrowingStore(super.prefs);

  @override
  Future<void> record(
    DateTime at,
    RelayAttemptOutcome outcome,
    RelayConfirmationScope scope,
  ) async => throw StateError('disk full');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _Relay relay;
  late _Tokens tokens;
  late DateTime now;

  void advance(Duration by) => now = now.add(by);

  DeviceTokenRegistry build({RelayConfirmationStore? confirmations}) =>
      DeviceTokenRegistry(
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
        confirmations: confirmations,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    relay = _Relay();
    tokens = _Tokens();
    now = DateTime.utc(2026, 10, 7, 8);
  });

  group('a failed daily confirmation survives a restart', () {
    test('the next cold launch sends the unchanged token again', () async {
      final first = build();
      await first.start();
      expect(relay.sent, hasLength(1));

      advance(const Duration(hours: 24));
      relay.error = const ApiException(statusCode: 403, message: 'no');
      await first.onResumed();
      expect(relay.sent, hasLength(2));

      // The process dies here. The in-memory pending flag goes with it.
      await first.stop();
      relay.error = null;
      advance(const Duration(minutes: 5));
      await build().start();
      expect(relay.sent, hasLength(3));
    });

    test(
      'the 24 hours count from the last accepted call, not a failure',
      () async {
        final registry = build();
        await registry.start();
        advance(const Duration(hours: 24));
        relay.error = const ApiException(statusCode: 403, message: 'no');
        await registry.onResumed();
        relay.error = null;
        advance(const Duration(minutes: 1));
        await registry.onResumed();
        expect(relay.sent, hasLength(3));
        // Accepted now, so the next resume is inside a fresh 24 hours.
        advance(const Duration(hours: 1));
        await registry.onResumed();
        expect(relay.sent, hasLength(3));
      },
    );

    test(
      'a relay that keeps refusing gets one call per resume, no loop',
      () async {
        final registry = build();
        await registry.start();
        advance(const Duration(hours: 24));
        relay.error = const ApiException(statusCode: 403, message: 'no');
        for (var i = 0; i < 3; i++) {
          await registry.onResumed();
        }
        // The launch call, then one per resume. A refusal is not retried inside
        // a call, so each resume costs one request.
        expect(relay.sent, hasLength(4));
      },
    );
  });

  group('registration is single flight', () {
    test(
      'a daily call in flight and a rotation: the newest token wins',
      () async {
        final registry = build();
        await registry.start();
        advance(const Duration(hours: 24));

        relay.hold = true;
        final daily = registry.onResumed();
        await _pump();
        tokens.rotate('token-2');
        await _pump();
        await relay.releaseNewestFirst();
        await daily;
        await _pump();

        expect(relay.sent.last, 'token-2');
        expect(prefs.getString(DeviceTokenRegistry.lastTokenKey), 'token-2');
        await registry.stop();
      },
    );

    test(
      'a rotation in flight and a daily call: one call, the new token',
      () async {
        final registry = build();
        await registry.start();
        advance(const Duration(hours: 24));

        relay.hold = true;
        tokens.rotate('token-2');
        await _pump();
        final daily = registry.onResumed();
        await _pump();
        await relay.releaseNewestFirst();
        await daily;
        await _pump();

        expect(relay.sent, ['token-1', 'token-2']);
        expect(prefs.getString(DeviceTokenRegistry.lastTokenKey), 'token-2');
        await registry.stop();
      },
    );

    test('two rotations close together end on the second', () async {
      final registry = build();
      await registry.start();

      relay.hold = true;
      tokens.rotate('token-2');
      await _pump();
      tokens.rotate('token-3');
      await _pump();
      await relay.releaseNewestFirst();
      await _pump();

      expect(relay.sent.last, 'token-3');
      expect(prefs.getString(DeviceTokenRegistry.lastTokenKey), 'token-3');
      await registry.stop();
    });

    test('two resumes close together send once', () async {
      final registry = build();
      await registry.start();
      advance(const Duration(hours: 24));

      relay.hold = true;
      final one = registry.onResumed();
      final two = registry.onResumed();
      await _pump();
      await relay.releaseNewestFirst();
      await Future.wait([one, two]);

      expect(relay.sent, hasLength(2));
    });

    test(
      'confirmNow while a call is in flight still sends afterwards',
      () async {
        final registry = build();
        await registry.start();
        advance(const Duration(hours: 24));

        relay.hold = true;
        final daily = registry.onResumed();
        await _pump();
        final now1 = registry.confirmNow();
        await _pump();
        await relay.releaseNewestFirst();
        await daily;
        expect(await now1, isTrue);
        expect(relay.sent, hasLength(3));
      },
    );
  });

  group('nothing new throws out of an unawaited call', () {
    test(
      'a store that cannot write does not stop a good call finishing',
      () async {
        final registry = build(confirmations: _ThrowingStore(prefs));
        await registry.start();
        expect(relay.sent, hasLength(1));
        expect(
          prefs.getString(DeviceTokenRegistry.lastTokenKey),
          'token-1',
          reason: 'the registry keeps its own record first',
        );
      },
    );

    test('a store that cannot write does not throw after a refusal', () async {
      final registry = build(confirmations: _ThrowingStore(prefs));
      relay.error = const ApiException(statusCode: 401, message: 'no');
      await registry.start();
      await registry.onResumed();
      expect(await registry.confirmNow(), isFalse);
    });

    test('a token the phone cannot read does not throw', () async {
      final registry = DeviceTokenRegistry(
        prefs: prefs,
        register: RegisterDeviceUsecase(
          relay,
          DeviceIdentityStore(prefs),
          tokens,
          platform: () => 'android',
        ),
        tokens: _ThrowingTokens(),
        appVersion: '0.1.0',
        wait: (_) async {},
        log: (_) {},
      );
      await registry.start();
      await registry.onResumed();
      expect(await registry.confirmNow(), isFalse);
    });
  });
}

class _ThrowingTokens implements PushTokenProvider {
  @override
  PushTokenKind get kind => PushTokenKind.fcm;

  @override
  Future<String> getToken() async => throw StateError('no token');

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}
