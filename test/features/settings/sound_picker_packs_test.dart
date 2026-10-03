import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:critalarm/core/sound/sound_pack_host.dart';
import 'package:critalarm/core/sound/sound_pack_repository.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/usecases/delete_user_sound_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/sound/fake_sound_pack_platform.dart';
import 'memory_alarm_sound_repository.dart';

class _NoPicker implements SoundFilePicker {
  @override
  Future<PickedSoundFile?> pickOne() async => null;

  @override
  Future<void> discard(String path) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const soundChannel = MethodChannel(SoundHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const bell = 'pack_library_boxing_bell';
  const pack = SoundPacks.library;

  late List<MethodCall> soundCalls;
  late FakeSoundPackPlatform store;
  late SoundPackRepository packs;
  late MemoryAlarmSoundRepository repository;
  late SoundPickerCubit cubit;

  SoundPickerCubit build() {
    final host = SoundHost();
    return SoundPickerCubit(
      repository,
      host,
      DeleteUserSoundUsecase(repository, host),
      _NoPicker(),
      SoundPeaksCache(host),
      platform: TargetPlatform.android,
      packs: packs,
    );
  }

  setUp(() {
    soundCalls = [];
    messenger.setMockMethodCallHandler(soundChannel, (call) async {
      soundCalls.add(call);
      return switch (call.method) {
        'readPeaks' => [0.5, 1.0],
        'capabilities' => <String, Object?>{},
        _ => true,
      };
    });
    store = FakeSoundPackPlatform();
    packs = SoundPackRepository(SoundPackHost());
    repository = MemoryAlarmSoundRepository();
    cubit = build();
  });

  tearDown(() async {
    await cubit.close();
    await packs.dispose();
    store.dispose();
    messenger.setMockMethodCallHandler(soundChannel, null);
  });

  test(
    'the picker shows the library pack, not downloaded, with no sounds',
    () async {
      await cubit.load();
      final entry = cubit.state.packs.single;
      expect(entry.pack.id, 'sound_pack_library');
      expect(entry.status.state, SoundPackState.notDownloaded);
      expect(cubit.state.packSounds, isEmpty);
    },
  );

  test('with no native side the picker shows no packs', () async {
    store.dispose();
    await cubit.load();
    expect(cubit.state.packs, isEmpty);
  });

  test('downloading shows progress, then lists the 23 sounds', () async {
    await cubit.load();
    await cubit.downloadPack(pack.id);
    expect(cubit.state.packs.single.status.state, SoundPackState.downloading);

    await store.send(pack.id, 'downloading', progress: 0.25);
    await pumpEventQueue();
    expect(cubit.state.packs.single.status.progress, 0.25);

    await store.send(pack.id, 'downloaded');
    await pumpEventQueue();
    expect(cubit.state.packs.single.status.state, SoundPackState.downloaded);
    expect(
      [for (final s in cubit.state.packSounds) s.id],
      pack.soundIds,
    );
    expect(cubit.state.packSounds.first.source, AlarmSoundSource.pack);
  });

  test(
    'a store that never answers does not hold the picker on loading',
    () async {
      await cubit.close();
      await packs.dispose();
      store.hangPackState = true;
      packs = SoundPackRepository(
        SoundPackHost(),
        storeTimeout: const Duration(milliseconds: 50),
      );
      cubit = build();

      final loading = cubit.load();
      await pumpEventQueue();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.bundled, hasLength(27));

      await loading;
      expect(cubit.state.packs.single.status.state, SoundPackState.failed);
      expect(cubit.state.packs.single.status.state.canDownload, isTrue);
    },
  );

  test('a late progress update does not undo a finished download', () async {
    await cubit.load();
    await cubit.downloadPack(pack.id);
    await store.send(pack.id, 'downloaded');
    await pumpEventQueue();
    expect(cubit.state.packs.single.status.state, SoundPackState.downloaded);

    await store.send(pack.id, 'downloading', progress: 0.9);
    await pumpEventQueue();
    expect(cubit.state.packs.single.status.state, SoundPackState.downloaded);
  });

  test(
    'a downloaded pack sound can be picked and previews from its file',
    () async {
      store.installed[bell] = '/sounds/$bell.ogg';
      await cubit.load(topicName: 'prod');
      await cubit.select(bell);
      expect(repository.assignments.soundIdFor('prod'), bell);

      final sound = cubit.state.packSounds.single;
      await cubit.togglePreview(sound);
      final preview = soundCalls.lastWhere((c) => c.method == 'startPreview');
      expect(preview.arguments, {
        'path': '/sounds/$bell.ogg',
        'is_asset': false,
      });
    },
  );

  test(
    'a topic whose pack sound went missing falls back to classic_siren',
    () async {
      await repository.setTopicSoundId('prod', bell);
      await repository.setDefaultSoundId(bell);

      await cubit.load(topicName: 'prod');

      expect(
        repository.assignments.soundIdFor('prod'),
        BundledSounds.fallbackId,
      );
      expect(repository.assignments.defaultSoundId, BundledSounds.fallbackId);
      expect(cubit.state.selectedSoundId, BundledSounds.fallbackId);
      expect(
        soundCalls.map((c) => c.method),
        contains('publishSoundAssignments'),
      );
    },
  );

  test('with no native side a pack sound keeps its topic', () async {
    store.dispose();
    await repository.setTopicSoundId('prod', bell);
    await cubit.load(topicName: 'prod');
    expect(repository.assignments.soundIdFor('prod'), bell);
  });

  test('a pack sound still on the device keeps its topic', () async {
    store.installed[bell] = '/sounds/$bell.ogg';
    await repository.setTopicSoundId('prod', bell);
    await cubit.load(topicName: 'prod');
    expect(repository.assignments.soundIdFor('prod'), bell);
    expect(cubit.state.selectedSoundId, bell);
  });
}
