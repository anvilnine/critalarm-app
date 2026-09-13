import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmSound', () {
    const sound = AlarmSound(
      id: 'pager_beep',
      name: 'Pager beep',
      source: AlarmSoundSource.bundled,
      path: 'assets/sounds/pager_beep.ogg',
      duration: Duration(seconds: 14),
    );

    test('survives a round trip through json', () {
      final restored = AlarmSound.fromJson(sound.toJson());
      expect(restored, equals(sound));
    });

    test('writes the duration as whole milliseconds', () {
      expect(sound.toJson()['duration'], 14000);
      expect(
        AlarmSound.fromJson({
          'id': 'x',
          'name': 'X',
          'source': 'user',
          'path': '/tmp/x.mp3',
          'duration': 2500,
        }).duration,
        const Duration(milliseconds: 2500),
      );
    });

    test('keeps the source it was given', () {
      expect(sound.source, AlarmSoundSource.bundled);
      expect(
        sound.copyWith(source: AlarmSoundSource.user).source,
        AlarmSoundSource.user,
      );
    });

    test('two sounds with the same fields are equal', () {
      expect(sound.copyWith(), equals(sound));
      expect(sound.copyWith(id: 'other'), isNot(equals(sound)));
    });
  });

  group('BundledSounds', () {
    test('ships exactly eight sounds', () {
      expect(BundledSounds.ids, hasLength(8));
      expect(BundledSounds.catalogue(), hasLength(8));
    });

    test('every id has a name and a length', () {
      for (final id in BundledSounds.ids) {
        expect(BundledSounds.englishNames[id], isNotNull, reason: id);
        expect(BundledSounds.durations[id], isNotNull, reason: id);
      }
    });

    test('every sound runs between 10 and 20 seconds', () {
      for (final sound in BundledSounds.catalogue()) {
        expect(
          sound.duration.inSeconds,
          inInclusiveRange(10, 20),
          reason: sound.id,
        );
      }
    });

    test('iOS points at the mp3 and Android at the ogg', () {
      expect(
        BundledSounds.assetPath('classic_siren', TargetPlatform.iOS),
        'assets/sounds/classic_siren.mp3',
      );
      expect(
        BundledSounds.assetPath('classic_siren', TargetPlatform.android),
        'assets/sounds/classic_siren.ogg',
      );
    });

    test('every bundled sound is marked as bundled', () {
      for (final sound in BundledSounds.catalogue()) {
        expect(sound.source, AlarmSoundSource.bundled);
      }
    });

    test('the fallback id is one of the eight', () {
      expect(BundledSounds.isBundled(BundledSounds.fallbackId), isTrue);
      expect(BundledSounds.isBundled('user_123'), isFalse);
    });

    test('names can be translated without touching the catalogue', () {
      final translated = BundledSounds.catalogue(
        nameOf: (id) => 'NAME:$id',
      );
      expect(translated.first.name, 'NAME:classic_siren');
    });
  });
}
