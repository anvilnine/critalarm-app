import 'package:critalarm/core/backup/backup_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('app.critalarm/backup');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('the verdict names', () {
    test('each name the phone answers with is read', () {
      expect(
        InstallMarkerVerdict.fromName('first'),
        InstallMarkerVerdict.first,
      );
      expect(InstallMarkerVerdict.fromName('same'), InstallMarkerVerdict.same);
      expect(
        InstallMarkerVerdict.fromName('moved'),
        InstallMarkerVerdict.moved,
      );
      expect(
        InstallMarkerVerdict.fromName('unknown'),
        InstallMarkerVerdict.unknown,
      );
    });

    test('a name nobody knows, or none, is not known and never moved', () {
      expect(InstallMarkerVerdict.fromName(null), InstallMarkerVerdict.unknown);
      expect(InstallMarkerVerdict.fromName(''), InstallMarkerVerdict.unknown);
      expect(
        InstallMarkerVerdict.fromName('Moved'),
        InstallMarkerVerdict.unknown,
      );
    });
  });

  group('the iPhone', () {
    const host = ChannelBackupHost();

    test('asks the phone where the install stands', () async {
      answer((_) => 'moved');
      expect(await host.installMarker(), InstallMarkerVerdict.moved);
      expect(calls.single.method, 'installMarker');
    });

    test('a phone that cannot answer is not known', () async {
      answer((_) => throw PlatformException(code: 'keychain'));
      expect(await host.installMarker(), InstallMarkerVerdict.unknown);
    });

    test('a build with no such channel is not known', () async {
      messenger.setMockMethodCallHandler(channel, null);
      expect(await host.installMarker(), InstallMarkerVerdict.unknown);
    });

    test('settling asks the phone and never throws', () async {
      answer((_) => true);
      await host.settleInstallMarker();
      expect(calls.single.method, 'settleInstallMarker');

      answer((_) => throw PlatformException(code: 'keychain'));
      await host.settleInstallMarker();
    });

    test('a folder is flagged by its path', () async {
      answer((_) => true);
      await host.excludeFromBackup('/app/support/alarm_look');
      expect(calls.single.method, 'excludeFromBackup');
      expect(calls.single.arguments, {'path': '/app/support/alarm_look'});
    });

    test('no path asks nothing, and a failure is not thrown', () async {
      answer((_) => throw PlatformException(code: 'io'));
      await host.excludeFromBackup('');
      expect(calls, isEmpty);
      await host.excludeFromBackup('/app/support/alarm_look');
      expect(calls, hasLength(1));
    });
  });

  group('Android and the web', () {
    const host = NoBackupHost();

    test('the install has never moved, and nothing is asked', () async {
      answer((_) => 'moved');
      expect(await host.installMarker(), InstallMarkerVerdict.same);
      await host.settleInstallMarker();
      await host.excludeFromBackup('/data/files/alarm_look');
      expect(calls, isEmpty);
    });
  });
}
