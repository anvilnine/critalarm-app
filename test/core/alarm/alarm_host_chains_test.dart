import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AlarmHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('each chain call names its method and arguments', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    final host = AlarmHost(channel);

    await host.cancelAllChains();
    await host.cancelChainsForTopic('prod');
    await host.syncChains({'prod': true, 'nas': false});

    expect(calls.map((call) => call.method), [
      'cancelAllChains',
      'cancelChainsForTopic',
      'syncChains',
    ]);
    expect(calls[1].arguments, {'topic': 'prod'});
    expect(calls[2].arguments, {
      'topics': {'prod': true, 'nas': false},
    });
  });

  test('a platform with no handler is a no-op', () async {
    final host = AlarmHost(channel);
    await host.cancelAllChains();
    await host.cancelChainsForTopic('prod');
    await host.syncChains(const {});
  });
}
