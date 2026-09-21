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

  group('shared files', () {
    test('taking a held file reads what the platform copied', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {'path': '/cache/memo.m4a', 'name': 'memo.m4a', 'size_bytes': 5};
      });
      final file = await SoundHost().takeIncomingAudio();
      expect(calls.single.method, 'takeIncomingAudio');
      expect(file?.path, '/cache/memo.m4a');
      expect(file?.name, 'memo.m4a');
      expect(file?.sizeBytes, 5);
    });

    test('nothing held, or no handler, is null', () async {
      expect(await SoundHost().takeIncomingAudio(), isNull);
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await SoundHost().takeIncomingAudio(), isNull);
    });

    test('a file shared while the app runs reaches the stream', () async {
      final host = SoundHost();
      final incoming = host.incomingAudio.first;
      await messenger.handlePlatformMessage(
        SoundHost.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('incomingAudio', {
            'path': '/cache/b.mp3',
            'name': 'b.mp3',
            'size_bytes': 9,
          }),
        ),
        (_) {},
      );
      expect((await incoming).path, '/cache/b.mp3');
    });
  });

  group('cropping', () {
    late List<MethodCall> calls;
    Object? answer;

    setUp(() {
      calls = [];
      answer = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return answer;
      });
    });

    test('importing sends the range and reads the saved size back', () async {
      answer = {'path': '/s/user_1.caf', 'duration_ms': 4000, 'size_bytes': 9};
      final imported = await SoundHost().importSound(
        sourcePath: '/tmp/song.mp3',
        id: 'user_1',
        start: const Duration(milliseconds: 42000),
        end: const Duration(milliseconds: 46000),
      );
      expect(calls.single.method, 'importSound');
      expect(calls.single.arguments, {
        'source_path': '/tmp/song.mp3',
        'id': 'user_1',
        'start_ms': 42000,
        'end_ms': 46000,
      });
      expect(imported!.path, '/s/user_1.caf');
      expect(imported.duration, const Duration(seconds: 4));
      expect(imported.sizeBytes, 9);
    });

    test('previewing a clip plays only its range of the file', () async {
      final started = await SoundHost().startClipPreview(
        path: '/tmp/song.mp3',
        start: const Duration(milliseconds: 1500),
        end: const Duration(milliseconds: 3000),
      );
      expect(started, isTrue);
      expect(calls.single.method, 'startPreview');
      expect(calls.single.arguments, {
        'path': '/tmp/song.mp3',
        'is_asset': false,
        'start_ms': 1500,
        'end_ms': 3000,
      });
    });

    test('a peaks read can carry a token and be cancelled by it', () async {
      answer = [0.5];
      final host = SoundHost();
      await host.readPeaks(
        path: '/tmp/song.mp3',
        isAsset: false,
        count: 100,
        cancelToken: 'crop_1',
      );
      await host.cancelPeaks('crop_1');
      expect(calls.first.arguments, containsPair('token', 'crop_1'));
      expect(calls.last.method, 'cancelPeaks');
      expect(calls.last.arguments, {'token': 'crop_1'});
    });
  });
}
