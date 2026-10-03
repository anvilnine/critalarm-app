import 'dart:async';

import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:critalarm/core/sound/sound_pack_host.dart';
import 'package:critalarm/core/sound/sound_pack_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_sound_pack_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pack = SoundPacks.library;
  late FakeSoundPackPlatform store;
  late SoundPackRepository repository;

  setUp(() {
    store = FakeSoundPackPlatform();
    repository = SoundPackRepository(SoundPackHost());
  });

  tearDown(() async {
    await repository.dispose();
    store.dispose();
  });

  void installAll() {
    for (final id in pack.soundIds) {
      store.installed[id] = '/sounds/$id.ogg';
    }
  }

  group('status', () {
    test('a pack the store has not sent is not downloaded', () async {
      expect(
        (await repository.status(pack)).state,
        SoundPackState.notDownloaded,
      );
    });

    test('a pack whose sounds are all copied is downloaded, with no store '
        'call', () async {
      installAll();
      store.storeState = 'unavailable';
      expect((await repository.status(pack)).state, SoundPackState.downloaded);
      expect(store.calls.map((c) => c.method), isNot(contains('packState')));
    });

    test(
      'a pack the store holds but whose copies are gone is copied again',
      () async {
        store.storeState = 'downloaded';
        expect(
          (await repository.status(pack)).state,
          SoundPackState.downloaded,
        );
        expect(store.installed.keys.toSet(), pack.soundIds.toSet());
      },
    );

    test('a copy that fails leaves the pack failed', () async {
      store
        ..storeState = 'downloaded'
        ..failCopy.add(pack.soundIds.first);
      expect((await repository.status(pack)).state, SoundPackState.failed);
    });

    test('a sideloaded build reports the pack unavailable', () async {
      store.storeState = 'unavailable';
      expect((await repository.status(pack)).state, SoundPackState.unavailable);
    });

    test('an iPhone before iOS 26 says so', () async {
      store.storeState = 'needs_newer_os';
      expect(
        (await repository.status(pack)).state,
        SoundPackState.needsNewerOs,
      );
    });

    test('with no native side the pack is unsupported', () async {
      store.dispose();
      expect(
        (await repository.status(pack)).state,
        SoundPackState.unsupported,
      );
    });
  });

  group('download', () {
    test('asks the store and reports it under way', () async {
      final status = await repository.download(pack);
      expect(status.state, SoundPackState.downloading);
      expect(store.calls.last.method, 'download');
      expect(store.calls.last.arguments, {'pack': 'sound_pack_library'});
    });

    test('progress from the store reaches the listeners', () async {
      final seen = <SoundPackStatus>[];
      final sub = repository.changes.listen((c) => seen.add(c.status));
      await store.send(pack.id, 'downloading', progress: 0.5);
      await pumpEventQueue();
      expect(
        seen.single,
        const SoundPackStatus(
          SoundPackState.downloading,
          progress: 0.5,
        ),
      );
      await sub.cancel();
    });

    test('a finished download is installed before it is reported', () async {
      final done = Completer<SoundPackChange>();
      final sub = repository.changes.listen(done.complete);
      await repository.download(pack);
      await store.send(pack.id, 'downloaded');
      final change = await done.future;
      expect(change.status.state, SoundPackState.downloaded);
      expect(store.installed.keys.toSet(), pack.soundIds.toSet());
      await sub.cancel();
    });

    test('a store that already has the pack installs it at once', () async {
      store
        ..downloadAnswer = 'downloaded'
        ..storeState = 'downloaded';
      expect(
        (await repository.download(pack)).state,
        SoundPackState.downloaded,
      );
      expect(store.installed, hasLength(23));
    });

    test('a failed download is reported as failed', () async {
      store.downloadAnswer = 'failed';
      expect((await repository.download(pack)).state, SoundPackState.failed);
    });

    test('changes for an unknown pack are ignored', () async {
      final seen = <SoundPackChange>[];
      final sub = repository.changes.listen(seen.add);
      await store.send('sound_pack_other', 'downloaded');
      await pumpEventQueue();
      expect(seen, isEmpty);
      await sub.cancel();
    });
  });

  group('installed sounds', () {
    test(
      'come back as pack sounds at their copied path, in pack order',
      () async {
        store.installed['pack_library_short_alarm'] =
            '/sounds/pack_library_short_alarm.ogg';
        store.installed['pack_library_buzzer_1'] =
            '/sounds/pack_library_buzzer_1.ogg';
        final sounds = await repository.installedSounds(
          nameOf: (id) => 'name of $id',
        );
        expect(sounds.map((s) => s.id), [
          'pack_library_buzzer_1',
          'pack_library_short_alarm',
        ]);
        final first = sounds.first;
        expect(first.source, AlarmSoundSource.pack);
        expect(first.path, '/sounds/pack_library_buzzer_1.ogg');
        expect(first.name, 'name of pack_library_buzzer_1');
        expect(first.duration, SoundPacks.info(first.id)!.duration);
      },
    );

    test('use the English name when nothing translates it', () async {
      store.installed['pack_library_boxing_bell'] = '/sounds/b.ogg';
      final sounds = await repository.installedSounds();
      expect(sounds.single.name, 'Boxing bell');
    });
  });

  group('fallback', () {
    test(
      'a pack sound that is assigned but not on the device is missing',
      () async {
        store.installed['pack_library_buzzer_1'] = '/sounds/b1.ogg';
        const assignments = SoundAssignments(
          defaultSoundId: 'pack_library_boxing_bell',
          perTopic: {
            'prod': 'pack_library_buzzer_1',
            'db': 'pager_beep',
            'old': 'pack_gone_forever',
          },
        );
        expect(await repository.missingAssigned(assignments), {
          'pack_library_boxing_bell',
          'pack_gone_forever',
        });
      },
    );

    test('nothing falls back when the platform cannot be asked', () async {
      store.dispose();
      const assignments = SoundAssignments(
        defaultSoundId: 'pack_library_boxing_bell',
        perTopic: {'old': 'pack_gone_forever'},
      );
      expect(await repository.missingAssigned(assignments), isEmpty);
    });

    test('nothing is missing when no pack sound is assigned', () async {
      const assignments = SoundAssignments(defaultSoundId: 'classic_siren');
      expect(await repository.missingAssigned(assignments), isEmpty);
      expect(store.calls, isEmpty);
    });
  });
}
