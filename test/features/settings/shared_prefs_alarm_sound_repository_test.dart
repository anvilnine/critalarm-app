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
    final before = prefs.getString(SharedPrefsAlarmSoundRepository.userSoundsKey);

    final result = await repository.updateUserSoundPeaks('b', [0.5]);

    expect(result.isSuccess(), isTrue);
    final sounds = (await repository.getUserSounds()).getOrThrow();
    expect([for (final s in sounds) s.id], ['a', 'c']);
    expect(
      prefs.getString(SharedPrefsAlarmSoundRepository.userSoundsKey),
      before,
    );
  });
}
