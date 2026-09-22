import 'dart:async';

import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_crop_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_crop_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_alarm_sound_repository.dart';

class _RecordingPicker implements SoundFilePicker {
  final List<String> discarded = [];

  @override
  Future<PickedSoundFile?> pickOne() async => null;

  @override
  Future<void> discard(String path) async => discarded.add(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SoundHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const file = PickedSoundFile(
    path: '/tmp/Mr Brightside.mp3',
    name: 'Mr Brightside.mp3',
    sizeBytes: 8 * 1024 * 1024,
  );

  late List<MethodCall> calls;
  late int probedMs;
  late List<double> filePeaks;
  late bool canImport;
  late Object? importAnswer;
  Completer<void>? holdImport;
  late MemoryAlarmSoundRepository repository;
  late _RecordingPicker picker;

  List<String> methods() => [for (final c in calls) c.method];

  setUp(() {
    calls = [];
    probedMs = 12000;
    filePeaks = [0.2, 0.4, 1.0];
    canImport = true;
    importAnswer = {
      'path': '/s/user_1.caf',
      'duration_ms': 12000,
      'size_bytes': 1000,
    };
    holdImport = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'capabilities':
          return {'can_import_sounds': canImport};
        case 'probeDuration':
          return probedMs;
        case 'readPeaks':
          final args = call.arguments as Map<Object?, Object?>;
          return args['token'] == null ? [0.5, 1.0] : filePeaks;
        case 'importSound':
          await holdImport?.future;
          return importAnswer;
      }
      return true;
    });
    repository = MemoryAlarmSoundRepository();
    picker = _RecordingPicker();
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  SoundCropCubit build({TargetPlatform platform = TargetPlatform.iOS}) {
    final host = SoundHost();
    return SoundCropCubit(
      host,
      ImportSoundUsecase(repository, host),
      picker,
      platform: platform,
    );
  }

  Future<void> platformSaysPreviewEnded(String path) async {
    await messenger.handlePlatformMessage(
      SoundHost.channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('previewEnded', {'path': path}),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  group('opening a file', () {
    test('a short file is ready with the whole file selected', () async {
      final cubit = build();
      await cubit.load(file);
      final state = cubit.state;
      expect(state.status, SoundCropStatus.ready);
      expect(state.name, 'Mr Brightside');
      expect(state.window!.start, Duration.zero);
      expect(state.window!.length, const Duration(seconds: 12));
      expect(state.peaks, filePeaks);
      await cubit.close();
    });

    test('peaks are read once at 100 a second, with a cancel token', () async {
      final cubit = build();
      await cubit.load(file);
      final read = calls.singleWhere((c) => c.method == 'readPeaks');
      final args = read.arguments as Map<Object?, Object?>;
      expect(args['path'], file.path);
      expect(args['count'], 1200);
      expect(args['token'], isA<String>());
      await cubit.close();
    });

    test('a long file opens at the max length on its loudest part', () async {
      probedMs = 100000;
      filePeaks = [
        for (var i = 0; i < 100; i++) i >= 50 && i < 80 ? 1.0 : 0.1,
      ];
      final cubit = build();
      await cubit.load(file);
      expect(cubit.state.window!.length, const Duration(milliseconds: 29500));
      expect(cubit.state.window!.start, const Duration(seconds: 50));
      await cubit.close();
    });

    test('Android allows a 60 second clip', () async {
      probedMs = 100000;
      final cubit = build(platform: TargetPlatform.android);
      await cubit.load(file);
      expect(cubit.state.window!.length, const Duration(seconds: 60));
      await cubit.close();
    });

    test('a file nothing can read fails as unreadable', () async {
      probedMs = 0;
      final cubit = build();
      await cubit.load(file);
      expect(cubit.state.status, SoundCropStatus.failed);
      expect(cubit.state.errorCode, 'unreadable');
      await cubit.close();
    });

    test('a file whose peaks come back empty fails as unreadable', () async {
      filePeaks = [];
      final cubit = build();
      await cubit.load(file);
      expect(cubit.state.status, SoundCropStatus.failed);
      expect(cubit.state.errorCode, 'unreadable');
      expect(cubit.state.window, isNull);
      await cubit.close();
    });

    test('a file over 20 minutes fails without reading peaks', () async {
      probedMs = 21 * 60 * 1000;
      final cubit = build();
      await cubit.load(file);
      expect(cubit.state.status, SoundCropStatus.failed);
      expect(cubit.state.errorCode, 'sourceTooLong');
      expect(methods(), isNot(contains('readPeaks')));
      await cubit.close();
    });

    test('a platform that cannot import sounds leaves at once', () async {
      canImport = false;
      final cubit = build();
      await cubit.load(file);
      expect(cubit.state.status, SoundCropStatus.unavailable);
      expect(methods(), isNot(contains('probeDuration')));
      await cubit.close();
    });
  });

  group('saving', () {
    test('saves the selected range under the name', () async {
      final cubit = build();
      await cubit.load(file);
      cubit
        ..rename('Chorus')
        ..dragStart(const Duration(seconds: 2))
        ..dragEnd(const Duration(seconds: 9));
      await cubit.save();
      final args =
          calls.singleWhere((c) => c.method == 'importSound').arguments
              as Map<Object?, Object?>;
      expect(args['start_ms'], 2000);
      expect(args['end_ms'], 9000);
      expect(cubit.state.status, SoundCropStatus.saved);
      expect(cubit.state.saved!.name, 'Chorus');
      expect(repository.sounds.single.name, 'Chorus');
      await cubit.close();
    });

    test('an empty name falls back to the file name', () async {
      final cubit = build();
      await cubit.load(file);
      cubit.rename('  ');
      expect(cubit.state.name, 'Mr Brightside');
      await cubit.close();
    });

    test('a failed save stays open and says so', () async {
      importAnswer = null;
      final cubit = build();
      await cubit.load(file);
      await cubit.save();
      expect(cubit.state.status, SoundCropStatus.ready);
      expect(cubit.state.errorCode, 'copyFailed');
      expect(repository.sounds, isEmpty);
      await cubit.close();
    });

    test('leaving without saving writes nothing and drops the copy', () async {
      final cubit = build();
      await cubit.load(file);
      await cubit.close();
      await cubit.pendingSave;
      await Future<void>.delayed(Duration.zero);
      expect(methods(), isNot(contains('importSound')));
      expect(repository.sounds, isEmpty);
      expect(picker.discarded, [file.path]);
    });

    test('leaving stops a running peak read', () async {
      final cubit = build();
      await cubit.load(file);
      await cubit.close();
      final read = calls.firstWhere((c) => c.method == 'readPeaks');
      final cancel = calls.singleWhere((c) => c.method == 'cancelPeaks');
      expect(
        (cancel.arguments as Map<Object?, Object?>)['token'],
        (read.arguments as Map<Object?, Object?>)['token'],
      );
    });

    test('a save that finishes after leaving still lands', () async {
      holdImport = Completer<void>();
      final cubit = build();
      await cubit.load(file);
      unawaited(cubit.save());
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      // The picked copy is still needed until the cut is done.
      expect(picker.discarded, isEmpty);

      holdImport!.complete();
      await cubit.pendingSave;
      await Future<void>.delayed(Duration.zero);

      expect(repository.sounds, hasLength(1));
      expect(picker.discarded, [file.path]);
    });
  });

  group('preview', () {
    test('play plays only the window of the unsaved file', () async {
      final cubit = build();
      await cubit.load(file);
      cubit.dragStart(const Duration(seconds: 3));
      await cubit.togglePlay();
      final play = calls.lastWhere((c) => c.method == 'startPreview');
      expect(play.arguments, {
        'path': file.path,
        'is_asset': false,
        'start_ms': 3000,
        'end_ms': 12000,
      });
      expect(cubit.state.isPlaying, isTrue);
      await cubit.close();
    });

    test('dragging stops playback', () async {
      final cubit = build();
      await cubit.load(file);
      await cubit.togglePlay();
      cubit.dragEnd(const Duration(seconds: 8));
      expect(cubit.state.isPlaying, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(methods().last, 'stopPreview');
      await cubit.close();
    });

    test('the end of this preview clears play, another one does not', () async {
      final cubit = build();
      await cubit.load(file);
      await cubit.togglePlay();
      await platformSaysPreviewEnded('/some/other.caf');
      expect(cubit.state.isPlaying, isTrue);
      await platformSaysPreviewEnded(file.path);
      expect(cubit.state.isPlaying, isFalse);
      await cubit.close();
    });
  });
}
