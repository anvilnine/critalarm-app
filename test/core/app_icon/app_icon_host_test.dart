import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AppIconHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Object? currentAnswer;

  setUp(() {
    calls = [];
    currentAnswer = 'default';
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'current' ? currentAnswer : null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('current reads the icon the platform names', () async {
    currentAnswer = 'pro_shades';

    expect(await AppIconHost().current(), AppIcon.shades);
    expect(calls.single.method, 'current');
  });

  test('current treats a name it does not know as the default', () async {
    currentAnswer = 'pro_from_a_newer_build';

    expect(await AppIconHost().current(), AppIcon.standard);
  });

  test('set sends the platform name', () async {
    expect(await AppIconHost().set(AppIcon.shadesCrown), isTrue);

    expect(calls.single.method, 'set');
    expect(calls.single.arguments, {'icon': 'pro_shades_crown'});
  });

  test('a platform with no handler cannot change its icon', () async {
    messenger.setMockMethodCallHandler(channel, null);
    final host = AppIconHost();

    expect(await host.current(), isNull);
    expect(await host.canChangeAppIcon(), isFalse);
    expect(await host.set(AppIcon.crowned), isFalse);
  });

  test('a platform that answers can change its icon', () async {
    expect(await AppIconHost().canChangeAppIcon(), isTrue);
  });

  test('a refused switch reports false', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });

    expect(await AppIconHost().set(AppIcon.crowned), isFalse);
    expect(await AppIconHost().current(), isNull);
  });
}
