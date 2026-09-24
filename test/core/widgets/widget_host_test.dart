import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(WidgetHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('write sends the whole snapshot as json', () async {
    await WidgetHost().write('{"v":1}');

    expect(calls.single.method, 'write');
    expect(calls.single.arguments, {'json': '{"v":1}'});
  });

  test('clear sends clear', () async {
    await WidgetHost().clear();

    expect(calls.single.method, 'clear');
  });

  test('a platform with no handler is quiet', () async {
    messenger.setMockMethodCallHandler(channel, null);

    await expectLater(WidgetHost().write('{}'), completes);
    await expectLater(WidgetHost().clear(), completes);
  });

  test('a platform error is quiet', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });

    await expectLater(WidgetHost().write('{}'), completes);
  });
}
