import 'package:critalarm/core/alarm/ring_screen_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(RingScreenHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  List<MethodCall> record({Object? Function(MethodCall call)? answer}) {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer?.call(call);
    });
    return calls;
  }

  test(
    'on an iPhone a start names the topic and a stop names nothing',
    () async {
      final calls = record();
      final host = RingScreenHost(isIos: true);

      await host.start(topic: 'prod-alerts');
      await host.stop();

      expect(calls.map((call) => call.method), ['start', 'stop']);
      expect(calls.first.arguments, {'topic': 'prod-alerts'});
      expect(calls.last.arguments, isNull);
    },
  );

  test('a start with no topic still reaches the phone', () async {
    final calls = record();

    await RingScreenHost(isIos: true).start(topic: null);

    expect(calls.single.arguments, {'topic': null});
  });

  test('off iOS the channel is never touched', () async {
    final calls = record();
    final host = RingScreenHost(isIos: false);

    await host.start(topic: 'prod-alerts');
    await host.stop();

    expect(calls, isEmpty);
  });

  test('a phone with no handler is not an error', () async {
    final host = RingScreenHost(isIos: true);

    await host.start(topic: 'prod-alerts');
    await host.stop();
  });

  test('a platform error is swallowed', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'nope');
    });
    final host = RingScreenHost(isIos: true);

    await host.start(topic: 'prod-alerts');
    await host.stop();
  });
}
