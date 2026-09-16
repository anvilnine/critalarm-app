import 'package:critalarm/core/push/apns_push_token_provider.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PushHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late PushHost host;

  void answerWith(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  /// Delivers a call the way the platform side would.
  Future<void> sendFromPlatform(String method, Object? arguments) =>
      messenger.handlePlatformMessage(
        PushHost.channelName,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );

  setUp(() {
    calls = [];
    answerWith((_) => null);
    host = PushHost();
  });

  tearDown(() async {
    await host.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('asks the platform for the current APNs token', () async {
    answerWith((call) => call.method == 'getApnsToken' ? 'a1b2' : null);
    expect(await host.apnsToken(), 'a1b2');
    expect(calls.single.method, 'getApnsToken');
  });

  test('a rotated token reaches the token stream', () async {
    final seen = host.tokenRefreshes.first;
    await sendFromPlatform('onApnsToken', 'c3d4');
    expect(await seen, 'c3d4');
  });

  test('an empty token is not reported as a rotation', () async {
    final seen = <String>[];
    final subscription = host.tokenRefreshes.listen(seen.add);
    await sendFromPlatform('onApnsToken', '');
    await sendFromPlatform('onApnsToken', null);
    await subscription.cancel();
    expect(seen, isEmpty);
  });

  test('a tapped incident notification becomes an incident route', () async {
    final route = host.deepLinks.first;
    await sendFromPlatform('onNotificationTap', {'incident_id': 'inc_9a8b7c'});
    expect(await route, '/incidents/inc_9a8b7c');
  });

  test('a tapped message notification falls back to the topic', () async {
    final route = host.deepLinks.first;
    await sendFromPlatform('onNotificationTap', {'topic': 'prod-db'});
    expect(await route, '/topics/prod-db');
  });

  test('a tap with nothing to open reports no route', () async {
    final seen = <String>[];
    final subscription = host.deepLinks.listen(seen.add);
    await sendFromPlatform('onNotificationTap', {'kind': 'p4'});
    await subscription.cancel();
    expect(seen, isEmpty);
  });

  test('a push arriving while the app is open is reported', () async {
    var seen = 0;
    final subscription = host.foregroundPushes.listen((_) => seen++);
    await sendFromPlatform('onPushReceived', null);
    await subscription.cancel();
    expect(seen, 1);
  });

  test('a tap sent live is not opened again when resume asks for it', () async {
    answerWith(
      (call) => call.method == 'takePending'
          ? {
              'tap': {'incident_id': 'inc_9a8b7c', 'tap_id': '1'},
            }
          : null,
    );
    final routes = <String>[];
    final subscription = host.deepLinks.listen(routes.add);
    await sendFromPlatform('onNotificationTap', {
      'incident_id': 'inc_9a8b7c',
      'tap_id': '1',
    });
    // The platform is still holding the same tap. Resume asks for it anyway.
    expect(await host.takePendingRoute(), isNull);
    await subscription.cancel();
    expect(routes, ['/incidents/inc_9a8b7c']);
  });

  test('a tap taken on resume is not opened again live', () async {
    answerWith(
      (call) => call.method == 'takePending'
          ? {
              'tap': {'incident_id': 'inc_9a8b7c', 'tap_id': '4'},
            }
          : null,
    );
    expect(await host.takePendingRoute(), '/incidents/inc_9a8b7c');
    final routes = <String>[];
    final subscription = host.deepLinks.listen(routes.add);
    await sendFromPlatform('onNotificationTap', {
      'incident_id': 'inc_9a8b7c',
      'tap_id': '4',
    });
    await subscription.cancel();
    expect(routes, isEmpty);
  });

  test('the next tap opens its screen', () async {
    final routes = <String>[];
    final subscription = host.deepLinks.listen(routes.add);
    await sendFromPlatform('onNotificationTap', {
      'incident_id': 'inc_1',
      'tap_id': '1',
    });
    await sendFromPlatform('onNotificationTap', {
      'incident_id': 'inc_2',
      'tap_id': '2',
    });
    await subscription.cancel();
    expect(routes, ['/incidents/inc_1', '/incidents/inc_2']);
  });

  test('a cold launch from a tap still hands back its route', () async {
    answerWith(
      (call) => call.method == 'takePending'
          ? {
              'tap': {'topic': 'prod-db', 'tap_id': '1'},
              'ack': 'inc_9a8b7c',
            }
          : null,
    );
    final acked = host.queuedAcks.first;
    expect(await host.takePendingRoute(), '/topics/prod-db');
    expect(await acked, 'inc_9a8b7c');
  });

  test('an ack queued natively reaches the ack stream', () async {
    final acked = host.queuedAcks.first;
    await sendFromPlatform('onAckQueued', 'inc_9a8b7c');
    expect(await acked, 'inc_9a8b7c');
  });

  test('setting the badge passes the count through', () async {
    await host.setBadgeCount(3);
    expect(calls.single.method, 'setBadgeCount');
    expect(calls.single.arguments, {'count': 3});
  });

  test('a platform with no handler answers null instead of throwing', () async {
    messenger.setMockMethodCallHandler(channel, null);
    expect(await host.apnsToken(), isNull);
    await host.setBadgeCount(0);
  });

  test('a platform error answers null instead of throwing', () async {
    answerWith((_) => throw PlatformException(code: 'unavailable'));
    expect(await host.apnsToken(), isNull);
  });

  group('ApnsPushTokenProvider', () {
    test('registers as an APNs token', () {
      expect(ApnsPushTokenProvider(host).kind, PushTokenKind.apns);
    });

    test('hands back the token the platform holds', () async {
      answerWith((_) => 'e5f6');
      expect(await ApnsPushTokenProvider(host).getToken(), 'e5f6');
    });

    test('throws before APNs has handed one out', () async {
      answerWith((_) => null);
      expect(
        ApnsPushTokenProvider(host).getToken(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
