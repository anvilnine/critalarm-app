import 'package:critalarm/core/account/account_tag.dart';
import 'package:critalarm/core/sound/own_sound_lock_flag.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String _one = accountTagFor('acc_1')!;
final String _two = accountTagFor('acc_2')!;

void main() {
  late SharedPreferences prefs;
  late OwnSoundLockFlag flag;

  Future<void> start([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    flag = OwnSoundLockFlag(prefs);
  }

  test('native keeps reading a plain boolean under the old key, and the '
      'tag sits in a key next to it', () async {
    await start();
    await flag.keepOnlyFor(_one);
    await flag.write(locked: true);
    expect(prefs.getBool('alarm_sound_own_locked'), isTrue);
    expect(prefs.getString('alarm_sound_own_locked_for'), _one);
    expect(flag.written, isTrue);

    await flag.write(locked: false);
    expect(prefs.getBool('alarm_sound_own_locked'), isFalse);
    expect(flag.written, isFalse);
  });

  test('a flag for this account is kept and trusted', () async {
    await start({
      'alarm_sound_own_locked': true,
      'alarm_sound_own_locked_for': _one,
    });
    expect(await flag.keepOnlyFor(_one), isFalse);
    expect(flag.written, isTrue);
    expect(prefs.getBool('alarm_sound_own_locked'), isTrue);
  });

  test('a flag for another account goes, and reads as never written', () async {
    await start({
      'alarm_sound_own_locked': true,
      'alarm_sound_own_locked_for': _one,
    });
    expect(await flag.keepOnlyFor(_two), isTrue);
    expect(flag.written, isNull);
    expect(prefs.containsKey('alarm_sound_own_locked'), isFalse);
    expect(prefs.containsKey('alarm_sound_own_locked_for'), isFalse);
    expect(await flag.keepOnlyFor(_two), isFalse);
  });

  test(
    'a flag with no tag, or a tag that is not text, belongs to nobody',
    () async {
      for (final initial in <Map<String, Object>>[
        {'alarm_sound_own_locked': true},
        {'alarm_sound_own_locked': true, 'alarm_sound_own_locked_for': 7},
      ]) {
        await start(initial);
        expect(await flag.keepOnlyFor(_one), isTrue, reason: '$initial');
        expect(flag.written, isNull);
        expect(prefs.containsKey('alarm_sound_own_locked'), isFalse);
      }
    },
  );

  test('before the account was read nothing is trusted', () async {
    await start({
      'alarm_sound_own_locked': true,
      'alarm_sound_own_locked_for': _one,
    });
    expect(flag.written, isNull);
  });

  test('with no account known the flag stays for native, is not trusted, '
      'and cannot be written', () async {
    await start({
      'alarm_sound_own_locked': true,
      'alarm_sound_own_locked_for': _one,
    });
    expect(await flag.keepOnlyFor(null), isFalse);
    expect(prefs.getBool('alarm_sound_own_locked'), isTrue);
    expect(flag.written, isNull);
    await expectLater(flag.write(locked: false), throwsStateError);
    expect(prefs.getBool('alarm_sound_own_locked'), isTrue);
  });

  test('a key that is not a boolean reads as never written', () async {
    await start({
      'alarm_sound_own_locked': 'true',
      'alarm_sound_own_locked_for': _one,
    });
    await flag.keepOnlyFor(_one);
    expect(flag.written, isNull);
  });

  test('clear takes both keys and says whether the flag was there', () async {
    await start({
      'alarm_sound_own_locked': false,
      'alarm_sound_own_locked_for': _one,
    });
    expect(await flag.clear(), isTrue);
    expect(prefs.getKeys(), isEmpty);
    expect(await flag.clear(), isFalse);
  });
}
