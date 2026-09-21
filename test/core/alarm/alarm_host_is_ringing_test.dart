import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AlarmHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('passes on what the platform says', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isRinging');
      return true;
    });
    expect(await AlarmHost(channel).isRinging(), isTrue);
  });

  test('null when the platform cannot tell', () async {
    expect(await AlarmHost(channel).isRinging(), isNull);
  });
}
