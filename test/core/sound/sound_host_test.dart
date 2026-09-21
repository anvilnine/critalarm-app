import 'package:critalarm/core/sound/sound_host.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SoundHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('publishing the sound choices calls the platform once', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });

    expect(await SoundHost().publishSoundAssignments(), isTrue);
    expect(calls.single.method, 'publishSoundAssignments');
  });

  test('a platform with no handler answers false', () async {
    expect(await SoundHost().publishSoundAssignments(), isFalse);
  });

  test('with no handler the platform cannot import sounds', () async {
    final capabilities = await SoundHost().capabilities();
    expect(capabilities.canImportSounds, isFalse);
  });

  test('the platform says when it can import sounds', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {'can_import_sounds': true},
    );
    final capabilities = await SoundHost().capabilities();
    expect(capabilities.canImportSounds, isTrue);
  });

  test('reading peaks with no handler gives an empty list', () async {
    expect(
      await SoundHost().readPeaks(path: '/x.caf', isAsset: false, count: 48),
      isEmpty,
    );
  });

  test('reading peaks passes the file and count, and clamps to 0..1', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return [0.0, 0.5, 1, 1.4, -0.2];
    });
    final peaks = await SoundHost().readPeaks(
      path: 'assets/sounds/pager_beep.mp3',
      isAsset: true,
      count: 5,
    );
    expect(peaks, [0.0, 0.5, 1.0, 1.0, 0.0]);
    expect(calls.single.method, 'readPeaks');
    expect(calls.single.arguments, {
      'path': 'assets/sounds/pager_beep.mp3',
      'is_asset': true,
      'count': 5,
    });
  });

  test('a peaks answer that is not a list gives an empty list', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => true);
    expect(
      await SoundHost().readPeaks(path: '/x.caf', isAsset: false, count: 48),
      isEmpty,
    );
  });

  test('the platform saying a preview ended reaches the stream', () async {
    final host = SoundHost();
    final ended = host.previewEnded.first;
    await messenger.handlePlatformMessage(
      SoundHost.channelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('previewEnded', {'path': '/sounds/a.caf'}),
      ),
      (_) {},
    );
    expect(await ended, '/sounds/a.caf');
  });
}
