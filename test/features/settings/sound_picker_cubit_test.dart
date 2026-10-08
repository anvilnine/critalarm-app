import 'dart:async';

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
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

  int asked = 0;

  @override
  Future<PickedSoundFile?> pickOne() async {
    asked++;
    return next;
  }

  @override
  Future<void> discard(String path) async => discarded.add(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(SoundHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;
  late List<MethodCall> previewCalls;
  late int probedMs;
  const peaks = [0.25, 1.0];

  /// When set, reading peaks for a user sound waits on this.
  Completer<void>? holdUserPeaks;

  /// When set, reading peaks for a bundled sound waits on this.
  Completer<void>? holdBundledPeaks;
  late int bundledReads;
  late Completer<void> userPeaksAsked;
  late MemoryAlarmSoundRepository repository;
  late _FixedPicker picker;
  late SoundPickerCubit cubit;
  late FeatureDecision ownSounds;
  late StreamController<Object?> ownSoundsChanges;

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
    previewCalls = [];
    probedMs = 4000;
    holdUserPeaks = null;
    holdBundledPeaks = null;
    bundledReads = 0;
    userPeaksAsked = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'startPreview') previewCalls.add(call);
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
    repository = MemoryAlarmSoundRepository();
    picker = _FixedPicker();
    final host = SoundHost();
    ownSounds = const FeatureDecision.open();
    ownSoundsChanges = StreamController<Object?>.broadcast();
    cubit = SoundPickerCubit(
      repository,
      host,
      DeleteUserSoundUsecase(repository, host),
      picker,
      SoundPeaksCache(host),
      platform: TargetPlatform.iOS,
      readOwnSounds: () => ownSounds,
      ownSoundsChanges: ownSoundsChanges.stream,
    );
    await cubit.load();
    calls.clear();
  });

  tearDown(() async {
    await cubit.close();
    await ownSoundsChanges.close();
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('own sounds locked', () {
    const locked = FeatureDecision.locked(Holding.pro);
    const file = PickedSoundFile(
      path: '/cache/a.mp3',
      name: 'a.mp3',
      sizeBytes: 4096,
    );

    Future<void> lock() async {
      ownSounds = locked;
      ownSoundsChanges.add(null);
      await Future<void>.delayed(Duration.zero);
    }

    test('the screen follows the decision', () async {
      expect(cubit.state.ownSoundsLocked, isFalse);
      await lock();
      expect(cubit.state.ownSoundsLocked, isTrue);
      expect(cubit.state.ownSounds, locked);

      ownSounds = const FeatureDecision.open();
      ownSoundsChanges.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.ownSoundsLocked, isFalse);
    });

    test('Pick a file never opens the platform picker', () async {
      picker.next = file;
      await lock();
      expect(await cubit.pickFile(), isNull);
      expect(picker.asked, 0);
    });

    test('Pick a file works again once it is open', () async {
      picker.next = file;
      expect(await cubit.pickFile(), file);
      expect(picker.asked, 1);
    });

    test('an own sound stays listed and cannot be picked', () async {
      repository.sounds.add(userSound);
      await cubit.load();
      await lock();
      calls.clear();

      expect([for (final s in cubit.state.userSounds) s.id], [userSound.id]);
      expect(cubit.state.isLocked(userSound), isTrue);
      await cubit.select(userSound.id);
      expect(repository.assignments.defaultSoundId, BundledSounds.fallbackId);
      expect(cubit.state.selectedSoundId, BundledSounds.fallbackId);
      expect(publishCount(), 0);
    });

    test('a built-in sound can still be picked', () async {
      await lock();
      await cubit.select('pager_beep');
      expect(repository.assignments.defaultSoundId, 'pager_beep');
      expect(cubit.state.isLocked(cubit.state.bundled.first), isFalse);
    });

    test('a locked own default shows the classic siren as ringing', () async {
      repository.sounds.add(userSound);
      await repository.setDefaultSoundId(userSound.id);
      await cubit.load();
      await lock();

      expect(cubit.state.selectedSoundId, userSound.id);
      expect(cubit.state.ringingSoundId, 'classic_siren');
      expect(cubit.state.ringsSomethingElse, isTrue);
      // The lock changes what rings, never what is saved.
      expect(repository.assignments.defaultSoundId, userSound.id);
    });

    test('a locked own topic sound shows the default as ringing', () async {
      repository.sounds.add(userSound);
      await repository.setDefaultSoundId('pager_beep');
      await repository.setTopicSoundId('prod', userSound.id);
      await cubit.load(topicName: 'prod');
      await lock();

      expect(cubit.state.selectedSoundId, userSound.id);
      expect(cubit.state.ringingSoundId, 'pager_beep');
      expect(repository.assignments.soundIdFor('prod'), userSound.id);
    });

    test('open again, the same own sound rings with nothing redone', () async {
      repository.sounds.add(userSound);
      await repository.setTopicSoundId('prod', userSound.id);
      await cubit.load(topicName: 'prod');
      await lock();
      expect(cubit.state.ringingSoundId, isNot(userSound.id));

      ownSounds = const FeatureDecision.open();
      ownSoundsChanges.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.ringingSoundId, userSound.id);
      expect(cubit.state.ringsSomethingElse, isFalse);
    });

    test('a plan that could not be read locks nothing', () async {
      repository.sounds.add(userSound);
      await repository.setDefaultSoundId(userSound.id);
      await cubit.load();
      ownSounds = const FeatureDecision.unread(Holding.pro);
      ownSoundsChanges.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.ownSoundsLocked, isFalse);
      expect(cubit.state.ringingSoundId, userSound.id);
      picker.next = file;
      expect(await cubit.pickFile(), file);
    });
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

  test('the picker lists all 27 built-in sounds in catalogue order', () {
    expect(
      [for (final s in cubit.state.bundled) s.id],
      BundledSounds.ids,
    );
    expect(cubit.state.bundled, hasLength(27));
  });

  test('a loop previews from its bundled asset', () async {
    final loop = cubit.state.bundled.singleWhere((s) => s.id == 'loop_dread');
    expect(loop.seamlessLoop, isTrue);
    await cubit.togglePreview(loop);
    expect(cubit.state.previewingSoundId, 'loop_dread');
    final args = previewCalls.single.arguments as Map<Object?, Object?>;
    expect(args['path'], 'assets/sounds/loop_dread.m4a');
    expect(args['is_asset'], isTrue);
  });

  test('an emergency sound previews from its bundled asset', () async {
    final horn = cubit.state.bundled.singleWhere(
      (s) => s.id == 'emergency_sos_horn',
    );
    await cubit.togglePreview(horn);
    expect(cubit.state.previewingSoundId, 'emergency_sos_horn');
    final args = previewCalls.single.arguments as Map<Object?, Object?>;
    expect(args['path'], 'assets/sounds/emergency_sos_horn.m4a');
    expect(args['is_asset'], isTrue);
  });

  test('an emergency sound picked for a topic is stored by its id', () async {
    await cubit.load(topicName: 'prod');
    await cubit.select('emergency_sos_horn');
    expect(repository.assignments.soundIdFor('prod'), 'emergency_sos_horn');
    expect(cubit.state.selectedSoundId, 'emergency_sos_horn');
  });

  test(
    'an emergency sound picked as the default is stored by its id',
    () async {
      await cubit.select('emergency_alarm_bell');
      expect(repository.assignments.defaultSoundId, 'emergency_alarm_bell');
    },
  );

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

  SoundPickerCubit freshCubit(SoundPeaksCache cache) {
    final host = SoundHost();
    return SoundPickerCubit(
      repository,
      host,
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
