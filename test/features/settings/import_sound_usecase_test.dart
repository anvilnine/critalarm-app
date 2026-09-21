import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_alarm_sound_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SoundHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Object? importAnswer;
  late MemoryAlarmSoundRepository repository;
  late ImportSoundUsecase usecase;

  const file = PickedSoundFile(
    path: '/tmp/Mr Brightside.mp3',
    name: 'Mr Brightside.mp3',
    sizeBytes: 8 * 1024 * 1024,
  );

  setUp(() {
    calls = [];
    importAnswer = {
      'path': '/s/new.caf',
      'duration_ms': 29500,
      'size_bytes': 2600000,
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'importSound' => importAnswer,
        'readPeaks' => [0.5, 1.0],
        _ => true,
      };
    });
    repository = MemoryAlarmSoundRepository();
    usecase = ImportSoundUsecase(repository, SoundHost());
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Map<Object?, Object?> importArgs() =>
      calls.firstWhere((c) => c.method == 'importSound').arguments
          as Map<Object?, Object?>;

  test('saves the chosen range of the file under the chosen name', () async {
    final result = await usecase(
      file: file,
      name: 'Chorus',
      start: const Duration(milliseconds: 42000),
      end: const Duration(milliseconds: 71500),
    );
    final sound = result.getOrNull()!;
    expect(importArgs()['start_ms'], 42000);
    expect(importArgs()['end_ms'], 71500);
    expect(importArgs()['source_path'], file.path);
    expect(sound.name, 'Chorus');
    expect(sound.path, '/s/new.caf');
    expect(sound.duration, const Duration(milliseconds: 29500));
    expect(sound.peaks, [0.5, 1.0]);
    expect(repository.sounds.single.id, sound.id);
  });

  test('an empty name falls back to the file name without extension', () async {
    final result = await usecase(
      file: file,
      name: '   ',
      start: Duration.zero,
      end: const Duration(seconds: 5),
    );
    expect(result.getOrNull()!.name, 'Mr Brightside');
  });

  test('a failed cut saves nothing', () async {
    importAnswer = null;
    final result = await usecase(
      file: file,
      name: 'Chorus',
      start: Duration.zero,
      end: const Duration(seconds: 5),
    );
    expect(result.exceptionOrNull()!.message, 'copyFailed');
    expect(repository.sounds, isEmpty);
  });

  test('a saved clip over 5 MB is deleted and nothing is kept', () async {
    importAnswer = {
      'path': '/s/new.caf',
      'duration_ms': 5000,
      'size_bytes': SoundImportLimits.maxBytes + 1,
    };
    final result = await usecase(
      file: file,
      name: 'Chorus',
      start: Duration.zero,
      end: const Duration(seconds: 5),
    );
    expect(result.exceptionOrNull()!.message, 'copyFailed');
    expect(repository.sounds, isEmpty);
    final delete = calls.singleWhere((c) => c.method == 'deleteSound');
    expect(delete.arguments, {'path': '/s/new.caf'});
  });
}
