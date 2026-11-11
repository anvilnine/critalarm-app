import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_alarm_sound_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AlarmSound sound(String id) => AlarmSound(
    id: id,
    name: id,
    source: AlarmSoundSource.user,
    path: '/sounds/$id.caf',
    duration: const Duration(seconds: 4),
  );

  late SharedPreferences prefs;
  late SharedPrefsAlarmSoundRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = SharedPrefsAlarmSoundRepository(prefs);
    for (final id in ['a', 'b', 'c']) {
      await repository.addUserSound(sound(id));
    }
  });

  test('peaks land on the right sound and the order stays', () async {
    final result = await repository.updateUserSoundPeaks('b', [0.1, 1]);
    expect(result.isSuccess(), isTrue);

    final sounds = (await repository.getUserSounds()).getOrThrow();
    expect([for (final s in sounds) s.id], ['a', 'b', 'c']);
    expect(sounds[1].peaks, [0.1, 1]);
    expect(sounds[0].peaks, isNull);
    expect(sounds[2].peaks, isNull);
  });

  test('a sound that is gone is not brought back', () async {
    await repository.deleteUserSound('b');
    final before = prefs.getString(
      SharedPrefsAlarmSoundRepository.userSoundsKey,
    );

    final result = await repository.updateUserSoundPeaks('b', [0.5]);

    expect(result.isSuccess(), isTrue);
    final sounds = (await repository.getUserSounds()).getOrThrow();
    expect([for (final s in sounds) s.id], ['a', 'c']);
    expect(
      prefs.getString(SharedPrefsAlarmSoundRepository.userSoundsKey),
      before,
    );
  });

  test('a missing pack sound falls back to Endless climb and keeps the user '
      'sounds', () async {
    await repository.setDefaultSoundId('pack_library_boxing_bell');
    await repository.setTopicSoundId('prod', 'pack_library_boxing_bell');
    await repository.setTopicSoundId('db', 'submarine_dive_horn');

    final result = await repository.fallBackFrom('pack_library_boxing_bell');
    expect(result.isSuccess(), isTrue);

    final assignments = (await repository.getAssignments()).getOrThrow();
    expect(assignments.defaultSoundId, 'loop_ascend');
    expect(assignments.soundIdFor('prod'), 'loop_ascend');
    expect(assignments.soundIdFor('db'), 'submarine_dive_horn');
    expect((await repository.getUserSounds()).getOrThrow(), hasLength(3));
  });

  group('removed and unset sounds', () {
    const removed = ['pulsing_klaxon', 'pager_beep', 'emergency_tone_ladder'];

    Future<SharedPrefsAlarmSoundRepository> withSaved(
      Map<String, Object> values,
    ) async {
      SharedPreferences.setMockInitialValues(values);
      return SharedPrefsAlarmSoundRepository(
        await SharedPreferences.getInstance(),
      );
    }

    test('nothing saved reads as Endless climb', () async {
      final repo = await withSaved({});
      final assignments = (await repo.getAssignments()).getOrThrow();
      expect(assignments.defaultSoundId, 'loop_ascend');
      expect(assignments.soundIdFor('prod'), 'loop_ascend');
    });

    test('an empty saved default reads as Endless climb', () async {
      final repo = await withSaved({
        SharedPrefsAlarmSoundRepository.defaultKey: '',
      });
      expect(repo.assignmentsNow().defaultSoundId, 'loop_ascend');
    });

    for (final id in removed) {
      test('$id as the default reads as Endless climb', () async {
        final repo = await withSaved({
          SharedPrefsAlarmSoundRepository.defaultKey: id,
        });
        expect(repo.assignmentsNow().defaultSoundId, 'loop_ascend');
      });

      test('$id on a topic reads as Endless climb, not the default', () async {
        final repo = await withSaved({
          SharedPrefsAlarmSoundRepository.defaultKey: 'classic_siren',
          SharedPrefsAlarmSoundRepository.perTopicKey: '{"prod":"$id"}',
        });
        final assignments = repo.assignmentsNow();
        expect(assignments.defaultSoundId, 'classic_siren');
        expect(assignments.soundIdFor('prod'), 'loop_ascend');
      });
    }

    test('sounds that still ship are left alone', () async {
      final repo = await withSaved({
        SharedPrefsAlarmSoundRepository.defaultKey: 'classic_siren',
        SharedPrefsAlarmSoundRepository.perTopicKey:
            '{"prod":"emergency_klaxon","db":"user_1",'
            '"web":"pack_library_boxing_bell"}',
      });
      final assignments = repo.assignmentsNow();
      expect(assignments.defaultSoundId, 'classic_siren');
      expect(assignments.perTopic, {
        'prod': 'emergency_klaxon',
        'db': 'user_1',
        'web': 'pack_library_boxing_bell',
      });
      expect(await repo.replaceRemovedSounds(), isFalse);
    });

    test('replaceRemovedSounds saves the replacement once', () async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsAlarmSoundRepository.defaultKey: 'pager_beep',
        SharedPrefsAlarmSoundRepository.perTopicKey:
            '{"prod":"pulsing_klaxon","db":"classic_siren"}',
      });
      final saved = await SharedPreferences.getInstance();
      final repo = SharedPrefsAlarmSoundRepository(saved);

      expect(await repo.replaceRemovedSounds(), isTrue);
      expect(
        saved.getString(SharedPrefsAlarmSoundRepository.defaultKey),
        'loop_ascend',
      );
      expect(
        saved.getString(SharedPrefsAlarmSoundRepository.perTopicKey),
        '{"prod":"loop_ascend","db":"classic_siren"}',
      );
      expect(await repo.replaceRemovedSounds(), isFalse);
    });

    test(
      'replaceRemovedSounds saves Endless climb when nothing was saved',
      () async {
        SharedPreferences.setMockInitialValues({});
        final saved = await SharedPreferences.getInstance();
        final repo = SharedPrefsAlarmSoundRepository(saved);

        expect(await repo.replaceRemovedSounds(), isTrue);
        expect(
          saved.getString(SharedPrefsAlarmSoundRepository.defaultKey),
          'loop_ascend',
        );
        expect(await repo.replaceRemovedSounds(), isFalse);
      },
    );
  });
}
