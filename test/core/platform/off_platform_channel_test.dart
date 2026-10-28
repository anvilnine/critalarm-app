import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/platform/off_platform_channel.dart';
import 'package:critalarm/core/sound/sound_pack_host.dart';
import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OffPlatformChannel', () {
    test('every call fails with MissingPluginException in Dart', () async {
      const channel = OffPlatformChannel('app.critalarm/test');
      await expectLater(
        channel.invokeMethod<void>('a'),
        throwsA(isA<MissingPluginException>()),
      );
      await expectLater(
        channel.invokeListMethod<int>('b'),
        throwsA(isA<MissingPluginException>()),
      );
      await expectLater(
        channel.invokeMapMethod<String, int>('c'),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('nothing reaches the platform messenger', () async {
      const name = 'app.critalarm/app_icon';
      var sent = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(const MethodChannel(name), (_) async {
              sent++;
              return 'pro_crowned';
            });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel(name),
          null,
        ),
      );

      final host = AppIconHost(const OffPlatformChannel(name));
      expect(await host.current(), isNull);
      expect(await host.set(AppIcon.standard), isFalse);
      expect(sent, 0);
    });

    test('the hosts hand back their usual off-platform defaults', () async {
      final before = OffPlatformChannel.stoppedCalls;
      final alarm = AlarmHost(const OffPlatformChannel(AlarmHost.channelName));
      expect(await alarm.isRinging(), isFalse);

      final packs = SoundPackHost(
        const OffPlatformChannel(SoundPackHost.channelName),
      );
      expect(await packs.installedPackSounds('pro', ['a']), isNull);

      final widgets = WidgetHost(
        const OffPlatformChannel(WidgetHost.channelName),
      );
      await widgets.write('{}');

      expect(OffPlatformChannel.stoppedCalls, greaterThan(before));
    });

    test('the event twin errors on listen', () async {
      const events = OffPlatformEventChannel('app.critalarm/motion/readings');
      await expectLater(
        events.receiveBroadcastStream(),
        emitsError(isA<MissingPluginException>()),
      );
    });
  });
}
