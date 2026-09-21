import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/usecases/delete_user_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps everything in memory, the same fallback rules as the real one.
class _MemoryRepository implements AlarmSoundRepository {
  SoundAssignments assignments = const SoundAssignments(
    defaultSoundId: BundledSounds.fallbackId,
  );
  final List<AlarmSound> sounds = [];

  @override
  Future<AppResult<SoundAssignments>> getAssignments() async =>
      assignments.toSuccess();

  @override
  Future<AppResult<Unit>> setDefaultSoundId(String soundId) async {
    assignments = assignments.withDefault(soundId);
    return unit.toSuccess();
  }

  @override
  Future<AppResult<Unit>> setTopicSoundId(
    String topicName,
    String? soundId,
  ) async {
    assignments = assignments.withTopicSound(topicName, soundId);
    return unit.toSuccess();
  }

  @override
  Future<AppResult<List<AlarmSound>>> getUserSounds() async =>
      List<AlarmSound>.of(sounds).toSuccess();

  @override
  Future<AppResult<Unit>> addUserSound(AlarmSound sound) async {
    sounds.add(sound);
    return unit.toSuccess();
  }

  @override
  Future<AppResult<Unit>> deleteUserSound(String soundId) async {
    sounds.removeWhere((s) => s.id == soundId);
    assignments = assignments.withSoundDeleted(
      soundId,
      fallbackSoundId: BundledSounds.fallbackId,
    );
    return unit.toSuccess();
  }
}

class _FixedPicker implements SoundFilePicker {
  PickedSoundFile? next;

  @override
  Future<PickedSoundFile?> pickOne() async => next;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SoundHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;
  late int probedMs;
  late _MemoryRepository repository;
  late _FixedPicker picker;
  late SoundPickerCubit cubit;

  int publishCount() =>
      calls.where((m) => m == 'publishSoundAssignments').length;

  const userSound = AlarmSound(
    id: 'user_1',
    name: 'Air horn',
    source: AlarmSoundSource.user,
    path: '/sounds/user_1.caf',
    duration: Duration(seconds: 4),
  );

  setUp(() async {
    calls = [];
    probedMs = 4000;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'probeDuration' => probedMs,
        'importSound' => {'path': '/sounds/new.caf', 'duration_ms': probedMs},
        'capabilities' => <String, Object?>{},
        _ => true,
      };
    });
    repository = _MemoryRepository();
    picker = _FixedPicker();
    final host = SoundHost();
    cubit = SoundPickerCubit(
      repository,
      host,
      ImportSoundUsecase(repository, host, platform: TargetPlatform.iOS),
      DeleteUserSoundUsecase(repository, host),
      picker,
      platform: TargetPlatform.iOS,
    );
    await cubit.load();
    calls.clear();
  });

  tearDown(() async {
    await cubit.close();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('the screen knows which platform it is on', () {
    expect(cubit.state.platform, TargetPlatform.iOS);
  });

  test('choosing a sound publishes the choices to the platform', () async {
    await cubit.select('pager_beep');
    expect(publishCount(), 1);
  });

  test('choosing a sound for a topic publishes too', () async {
    await cubit.load(topicName: 'prod');
    calls.clear();
    await cubit.select('pager_beep');
    expect(repository.assignments.soundIdFor('prod'), 'pager_beep');
    expect(publishCount(), 1);
  });

  test('deleting a sound publishes after the fallback has moved', () async {
    repository.sounds.add(userSound);
    await repository.setDefaultSoundId(userSound.id);
    await cubit.deleteUserSound(userSound.id);
    expect(repository.assignments.defaultSoundId, BundledSounds.fallbackId);
    expect(publishCount(), 1);
    expect(calls.last, 'publishSoundAssignments');
  });

  test('importing a sound publishes', () async {
    picker.next = const PickedSoundFile(
      path: '/tmp/horn.mp3',
      name: 'horn.mp3',
      sizeBytes: 1024,
    );
    await cubit.importSound();
    expect(cubit.state.userSounds, hasLength(1));
    expect(publishCount(), 1);
  });

  test(
    'an iOS import over 29.5 seconds is turned away and publishes nothing',
    () async {
      probedMs = 29501;
      picker.next = const PickedSoundFile(
        path: '/tmp/long.mp3',
        name: 'long.mp3',
        sizeBytes: 1024,
      );
      await cubit.importSound();
      expect(cubit.state.errorCode, 'tooLong');
      expect(cubit.state.userSounds, isEmpty);
      expect(publishCount(), 0);
    },
  );
}
