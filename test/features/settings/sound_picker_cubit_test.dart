import 'dart:async';

import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
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
  Future<AppResult<Unit>> updateUserSoundPeaks(
    String soundId,
    List<double> peaks,
  ) async {
    final index = sounds.indexWhere((s) => s.id == soundId);
    if (index >= 0) sounds[index] = sounds[index].copyWith(peaks: peaks);
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
  const peaks = [0.25, 1.0];

  /// When set, reading peaks for a user sound waits on this.
  Completer<void>? holdUserPeaks;

  /// When set, reading peaks for a bundled sound waits on this.
  Completer<void>? holdBundledPeaks;
  late int bundledReads;
  late Completer<void> userPeaksAsked;
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
    holdUserPeaks = null;
    holdBundledPeaks = null;
    bundledReads = 0;
    userPeaksAsked = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'readPeaks') {
        final args = call.arguments as Map<Object?, Object?>;
        if (args['is_asset'] != true) {
          if (!userPeaksAsked.isCompleted) userPeaksAsked.complete();
          await holdUserPeaks?.future;
        } else {
          bundledReads++;
          await holdBundledPeaks?.future;
        }
        return peaks;
      }
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
      SoundPeaksCache(host),
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

  test('importing a sound saves its peaks with it', () async {
    picker.next = const PickedSoundFile(
      path: '/tmp/horn.mp3',
      name: 'horn.mp3',
      sizeBytes: 1024,
    );
    await cubit.importSound();
    expect(cubit.state.userSounds.single.peaks, peaks);
    expect(repository.sounds.single.peaks, peaks);
  });

  test('bundled rows get their peaks on load', () async {
    for (final sound in cubit.state.bundled) {
      expect(sound.peaks, peaks, reason: sound.id);
    }
  });

  SoundPickerCubit freshCubit(SoundPeaksCache cache) {
    final host = SoundHost();
    return SoundPickerCubit(
      repository,
      host,
      ImportSoundUsecase(repository, host, platform: TargetPlatform.iOS),
      DeleteUserSoundUsecase(repository, host),
      picker,
      cache,
      platform: TargetPlatform.iOS,
    );
  }

  test(
    'bundled peaks all show in one update once every read is done',
    () async {
      holdBundledPeaks = Completer<void>();
      bundledReads = 0;
      final fresh = freshCubit(SoundPeaksCache(SoundHost()));
      final states = <List<List<double>?>>[];
      final sub = fresh.stream.listen(
        (s) => states.add([for (final b in s.bundled) b.peaks]),
      );
      final loading = fresh.load();
      while (bundledReads < fresh.state.bundled.length) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(fresh.state.isLoadingPeaks, isTrue);
      holdBundledPeaks!.complete();
      await loading;
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      final withAnyPeaks = states.where((p) => p.any((e) => e != null));
      expect(withAnyPeaks.first, everyElement(peaks));
      expect(fresh.state.isLoadingPeaks, isFalse);
      await fresh.close();
    },
  );

  test('peaks read on an earlier open are there on the first frame', () async {
    final cache = SoundPeaksCache(SoundHost());
    final first = freshCubit(cache);
    await first.load();
    await first.close();

    final second = freshCubit(cache);
    final firstState = second.stream.first;
    final loading = second.load();
    final shown = await firstState;
    await loading;
    for (final sound in shown.bundled) {
      expect(sound.peaks, peaks, reason: sound.id);
    }
    await second.close();
  });

  Future<void> previewEnded(String path) async {
    await messenger.handlePlatformMessage(
      SoundHost.channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('previewEnded', {'path': path}),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  test('the platform ending a preview clears the playing row', () async {
    final first = cubit.state.bundled.first;
    await cubit.togglePreview(first);
    expect(cubit.state.previewingSoundId, first.id);

    await previewEnded(first.path);

    expect(cubit.state.previewingSoundId, isNull);
  });

  test('a late end for an older preview leaves the new one playing', () async {
    final first = cubit.state.bundled.first;
    final second = cubit.state.bundled[1];
    await cubit.togglePreview(first);
    await cubit.togglePreview(second);

    await previewEnded(first.path);

    expect(cubit.state.previewingSoundId, second.id);
  });

  test('old user sounds get their peaks filled in and saved', () async {
    repository.sounds.add(userSound);
    await cubit.load();
    expect(cubit.state.userSounds.single.peaks, peaks);
    expect(repository.sounds.single.peaks, peaks);
  });

  test('a sound deleted while its peaks are read stays deleted', () async {
    repository.sounds.add(userSound);
    holdUserPeaks = Completer<void>();
    final loading = cubit.load();
    await userPeaksAsked.future;

    await cubit.deleteUserSound(userSound.id);
    holdUserPeaks!.complete();
    await loading;

    expect(cubit.state.userSounds, isEmpty);
    expect(repository.sounds, isEmpty);
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
