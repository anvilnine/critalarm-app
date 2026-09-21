import 'dart:async';

import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/usecases/delete_user_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_alarm_sound_repository.dart';

class _FixedPicker implements SoundFilePicker {
  PickedSoundFile? next;
  final List<String> discarded = [];

  @override
  Future<PickedSoundFile?> pickOne() async => next;

  @override
  Future<void> discard(String path) async => discarded.add(path);
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
  late Completer<void> userPeaksAsked;
  late MemoryAlarmSoundRepository repository;
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
    userPeaksAsked = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'readPeaks') {
        final args = call.arguments as Map<Object?, Object?>;
        if (args['is_asset'] != true) {
          if (!userPeaksAsked.isCompleted) userPeaksAsked.complete();
          await holdUserPeaks?.future;
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
    repository = MemoryAlarmSoundRepository();
    picker = _FixedPicker();
    final host = SoundHost();
    cubit = SoundPickerCubit(
      repository,
      host,
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

  test('bundled rows get their peaks on load', () async {
    for (final sound in cubit.state.bundled) {
      expect(sound.peaks, peaks, reason: sound.id);
    }
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

  test('a picked file that passes the check goes on to the cropper', () async {
    picker.next = const PickedSoundFile(
      path: '/tmp/horn.mp3',
      name: 'horn.mp3',
      sizeBytes: 1024,
    );
    final file = await cubit.pickFile();
    expect(file, same(picker.next));
    expect(cubit.state.errorCode, isNull);
    expect(picker.discarded, isEmpty);
  });

  test('backing out of the picker gives nothing and no error', () async {
    expect(await cubit.pickFile(), isNull);
    expect(cubit.state.errorCode, isNull);
  });

  test('a picked file that fails the check is dropped with an error', () async {
    picker.next = const PickedSoundFile(
      path: '/tmp/film.mov',
      name: 'film.mov',
      sizeBytes: 1024,
    );
    expect(await cubit.pickFile(), isNull);
    expect(cubit.state.errorCode, 'unsupportedFormat');
    expect(picker.discarded, ['/tmp/film.mov']);
  });

  test('a picked file over 100 MB is dropped before any decode', () async {
    picker.next = const PickedSoundFile(
      path: '/tmp/big.mp3',
      name: 'big.mp3',
      sizeBytes: 101 * 1024 * 1024,
    );
    expect(await cubit.pickFile(), isNull);
    expect(cubit.state.errorCode, 'tooLarge');
    expect(calls, isNot(contains('probeDuration')));
  });

  test('after the cropper closes the list is read again', () async {
    repository.sounds.add(userSound);
    await cubit.reloadAfterCrop();
    expect(cubit.state.userSounds, [userSound]);
    expect(cubit.state.selectedSoundId, isNot(userSound.id));
    expect(publishCount(), 1);
  });

  test('a save that finishes after the cropper closed still shows', () async {
    final save = Completer<void>();
    final reload = cubit.reloadAfterCrop(save.future);
    repository.sounds.add(userSound);
    save.complete();
    await reload;
    expect(cubit.state.userSounds, [userSound]);
  });
}
