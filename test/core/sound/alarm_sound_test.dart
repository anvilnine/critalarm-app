import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmSound', () {
    const sound = AlarmSound(
      id: 'submarine_dive_horn',
      name: 'Submarine dive horn',
      source: AlarmSoundSource.bundled,
      path: 'assets/sounds/submarine_dive_horn.ogg',
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

    test('a sound saved before peaks existed reads back with none', () {
      final restored = AlarmSound.fromJson({
        'id': 'user_1',
        'name': 'Horn',
        'source': 'user',
        'path': '/tmp/user_1.caf',
        'duration': 4000,
      });
      expect(restored.peaks, isNull);
    });

    test('a sound saved before seamless loops existed is not one', () {
      final restored = AlarmSound.fromJson({
        'id': 'user_1',
        'name': 'Horn',
        'source': 'user',
        'path': '/tmp/user_1.caf',
        'duration': 4000,
      });
      expect(restored.seamlessLoop, isFalse);
    });

    test('a user sound cannot claim to be a seamless loop', () {
      final restored = AlarmSound.fromJson({
        'id': 'loop_dread',
        'name': 'Horn',
        'source': 'user',
        'path': '/tmp/user_1.caf',
        'duration': 4000,
        'seamlessLoop': true,
      });
      expect(restored.seamlessLoop, isFalse);
      expect(restored.toJson().containsKey('seamlessLoop'), isFalse);
    });

    test('a bundled loop restored from json is still a seamless loop', () {
      final loop = BundledSounds.catalogue().singleWhere(
        (s) => s.id == 'loop_dread',
      );
      expect(AlarmSound.fromJson(loop.toJson()).seamlessLoop, isTrue);
    });

    test('a bundled sound that is not a loop stays not one', () {
      final restored = AlarmSound.fromJson({
        'id': 'pager_beep',
        'name': 'Pager beep',
        'source': 'bundled',
        'path': 'assets/sounds/pager_beep.ogg',
        'duration': 14000,
        'seamlessLoop': true,
      });
      expect(restored.seamlessLoop, isFalse);
    });

    test('peaks survive a round trip through json', () {
      final withPeaks = sound.copyWith(peaks: const [0, 0.5, 1]);
      final restored = AlarmSound.fromJson(withPeaks.toJson());
      expect(restored.peaks, [0, 0.5, 1]);
      expect(restored, equals(withPeaks));
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
    // Stored against topics, so the ids are fixed. Three were taken out after
    // 1.1.0 and are in [BundledSounds.removedIds].
    const removed = ['pulsing_klaxon', 'pager_beep', 'emergency_tone_ladder'];
    const firstSix = [
      'classic_siren',
      'marimba_escalator',
      'soft_to_loud_ramp',
      'submarine_dive_horn',
      'rising_synth_sweep',
      'plain_loud_beep',
    ];
    const emergency = [
      'emergency_hilo_siren',
      'emergency_wail_siren',
      'emergency_yelp_siren',
      'emergency_windup_siren',
      'emergency_klaxon',
      'emergency_sos_beeper',
      'emergency_sos_horn',
      'emergency_rapid_beeper',
      'emergency_red_alert',
      'emergency_endless_siren',
      'emergency_speeding_beeper',
      'emergency_proximity',
      'emergency_alarm_bell',
    ];
    const loops = [
      'loop_ascend',
      'loop_dread',
      'loop_chiprun',
      'loop_glockslide',
      'loop_royalroad',
    ];

    test('ships 24 sounds', () {
      expect(BundledSounds.ids, hasLength(24));
      expect(BundledSounds.catalogue(), hasLength(24));
    });

    test('Endless climb first, then the first six, the emergency 13 and the '
        'other four loops', () {
      expect(BundledSounds.ids, [
        'loop_ascend',
        ...firstSix,
        ...emergency,
        ...loops.where((id) => id != 'loop_ascend'),
      ]);
    });

    test('the picker lists Endless climb first', () {
      final catalogue = BundledSounds.catalogue();
      expect(catalogue.first.id, 'loop_ascend');
      expect(catalogue.first.name, 'Endless climb');
    });

    test('the removed sounds are gone everywhere', () {
      expect(BundledSounds.removedIds, removed.toSet());
      for (final id in removed) {
        expect(BundledSounds.ids, isNot(contains(id)), reason: id);
        expect(BundledSounds.isBundled(id), isFalse, reason: id);
        expect(BundledSounds.iosExtensions, isNot(contains(id)), reason: id);
        expect(BundledSounds.englishNames, isNot(contains(id)), reason: id);
        for (final ext in ['mp3', 'm4a', 'ogg']) {
          expect(
            File('assets/sounds/$id.$ext').existsSync(),
            isFalse,
            reason: '$id.$ext',
          );
        }
        expect(
          File('ios/Runner/Haptics/$id.ahap').existsSync(),
          isFalse,
          reason: id,
        );
      }
      final licences = File('assets/sounds/LICENSES.md').readAsStringSync();
      for (final id in removed) {
        expect(licences, isNot(contains('`$id`')), reason: id);
      }
    });

    test('no translation still names a removed sound', () {
      for (final file in Directory('assets/translations').listSync()) {
        if (file is! File || !file.path.endsWith('.json')) continue;
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final names =
            (json['sound_library'] as Map<String, dynamic>)['names']
                as Map<String, dynamic>;
        for (final id in removed) {
          expect(names, isNot(contains(id)), reason: '${file.path} $id');
        }
      }
    });

    test('a removed sound is replaced by Endless climb', () {
      for (final id in removed) {
        expect(BundledSounds.replacingRemoved(id), 'loop_ascend', reason: id);
      }
      expect(BundledSounds.replacingRemoved('classic_siren'), 'classic_siren');
      expect(BundledSounds.replacingRemoved('user_1'), 'user_1');
      expect(
        BundledSounds.replacingRemoved('pack_library_boxing_bell'),
        'pack_library_boxing_bell',
      );
    });

    test('the loops have their names', () {
      expect(
        {for (final id in loops) id: BundledSounds.englishNames[id]},
        {
          'loop_ascend': 'Endless climb',
          'loop_dread': 'Falling dread',
          'loop_chiprun': 'Chip run',
          'loop_glockslide': 'Glock slide',
          'loop_royalroad': 'Royal road',
        },
      );
    });

    test('every loop is exactly 28.8 seconds', () {
      for (final id in loops) {
        expect(
          BundledSounds.durations[id],
          const Duration(milliseconds: 28800),
          reason: id,
        );
      }
    });

    test('only the five loops are marked as seamless loops', () {
      expect(BundledSounds.seamlessLoops, loops.toSet());
      for (final sound in BundledSounds.catalogue()) {
        expect(sound.seamlessLoop, loops.contains(sound.id), reason: sound.id);
      }
    });

    test('the loop flag is the same on both platforms', () {
      final ios = BundledSounds.catalogue(platform: TargetPlatform.iOS);
      // Named on purpose: this test is about Android, whatever the default.
      // ignore: avoid_redundant_argument_values
      final android = BundledSounds.catalogue(platform: TargetPlatform.android);
      List<String> flagged(List<AlarmSound> sounds) => [
        for (final s in sounds)
          if (s.seamlessLoop) s.id,
      ];
      expect(flagged(ios), loops);
      expect(flagged(android), flagged(ios));
    });

    test('the first six keep their lengths', () {
      expect(
        {for (final id in firstSix) id: BundledSounds.durations[id]},
        const {
          'classic_siren': Duration(seconds: 16),
          'marimba_escalator': Duration(milliseconds: 15600),
          'soft_to_loud_ramp': Duration(seconds: 15),
          'submarine_dive_horn': Duration(seconds: 15),
          'rising_synth_sweep': Duration(seconds: 15),
          'plain_loud_beep': Duration(seconds: 12),
        },
      );
    });

    test('the emergency sounds have the lengths the encoder wrote', () {
      expect(
        {for (final id in emergency) id: BundledSounds.durations[id]},
        const {
          'emergency_hilo_siren': Duration(milliseconds: 16200),
          'emergency_wail_siren': Duration(seconds: 16),
          'emergency_yelp_siren': Duration(milliseconds: 15840),
          'emergency_windup_siren': Duration(milliseconds: 16500),
          'emergency_klaxon': Duration(seconds: 16),
          'emergency_sos_beeper': Duration(seconds: 17),
          'emergency_sos_horn': Duration(milliseconds: 17340),
          'emergency_rapid_beeper': Duration(seconds: 16),
          'emergency_red_alert': Duration(milliseconds: 16250),
          'emergency_endless_siren': Duration(seconds: 16),
          'emergency_speeding_beeper': Duration(seconds: 16),
          'emergency_proximity': Duration(seconds: 16),
          'emergency_alarm_bell': Duration(seconds: 16),
        },
      );
    });

    test('every id has a name and a length', () {
      for (final id in BundledSounds.ids) {
        expect(BundledSounds.englishNames[id], isNotNull, reason: id);
        expect(BundledSounds.durations[id], isNotNull, reason: id);
      }
      expect(BundledSounds.englishNames.keys, BundledSounds.ids);
    });

    test('no two sounds share a name', () {
      final names = BundledSounds.englishNames.values.toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('every id has both asset files', () {
      for (final id in BundledSounds.ids) {
        for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
          final file = File(BundledSounds.assetPath(id, platform));
          expect(file.existsSync(), isTrue, reason: file.path);
          expect(file.lengthSync(), greaterThan(0), reason: file.path);
        }
      }
    });

    test('every id has the same name in the English translations', () {
      final json =
          jsonDecode(File('assets/translations/en.json').readAsStringSync())
              as Map<String, dynamic>;
      final names =
          (json['sound_library'] as Map<String, dynamic>)['names']
              as Map<String, dynamic>;
      expect(names, {
        ...BundledSounds.englishNames,
        for (final pack in SoundPacks.all)
          for (final sound in pack.sounds) sound.id: sound.englishName,
      });
    });

    test('LICENSES.md lists every sound', () {
      final licences = File('assets/sounds/LICENSES.md').readAsStringSync();
      for (final id in BundledSounds.ids) {
        expect(licences, contains('`$id`'), reason: id);
      }
    });

    test('every sound but the loops runs between 10 and 20 seconds', () {
      for (final sound in BundledSounds.catalogue()) {
        if (sound.seamlessLoop) continue;
        expect(
          sound.duration.inSeconds,
          inInclusiveRange(10, 20),
          reason: sound.id,
        );
      }
    });

    test('every loop stays under the 30 second iOS sound limit', () {
      for (final sound in BundledSounds.catalogue()) {
        if (!sound.seamlessLoop) continue;
        expect(sound.duration, lessThan(const Duration(seconds: 30)));
      }
    });

    test('iOS plays the first six as mp3, Android as ogg', () {
      for (final id in firstSix) {
        expect(
          BundledSounds.assetPath(id, TargetPlatform.iOS),
          'assets/sounds/$id.mp3',
        );
        expect(
          BundledSounds.assetPath(id, TargetPlatform.android),
          'assets/sounds/$id.ogg',
        );
      }
    });

    test('macOS plays the iPhone files, since it has no ogg reader', () {
      for (final id in BundledSounds.ids) {
        expect(
          BundledSounds.assetPath(id, TargetPlatform.macOS),
          BundledSounds.assetPath(id, TargetPlatform.iOS),
          reason: id,
        );
      }
    });

    test('iOS plays the emergency sounds and loops as m4a, Android as ogg', () {
      for (final id in [...emergency, ...loops]) {
        expect(
          BundledSounds.assetPath(id, TargetPlatform.iOS),
          'assets/sounds/$id.m4a',
        );
        expect(
          BundledSounds.assetPath(id, TargetPlatform.android),
          'assets/sounds/$id.ogg',
        );
      }
    });

    test('the catalogue carries the per-sound iOS path', () {
      final ios = BundledSounds.catalogue(platform: TargetPlatform.iOS);
      expect(
        ios.firstWhere((s) => s.id == 'classic_siren').path,
        'assets/sounds/classic_siren.mp3',
      );
      expect(
        ios.firstWhere((s) => s.id == 'emergency_klaxon').path,
        'assets/sounds/emergency_klaxon.m4a',
      );
    });

    test('every id has an iOS extension', () {
      expect(BundledSounds.iosExtensions.keys, BundledSounds.ids);
    });

    test('asking for the extension of an unknown id throws', () {
      expect(
        () => BundledSounds.extensionFor('user_1', TargetPlatform.iOS),
        throwsArgumentError,
      );
    });

    test('no emergency sound or loop ships an mp3', () {
      for (final id in [...emergency, ...loops]) {
        expect(File('assets/sounds/$id.mp3').existsSync(), isFalse, reason: id);
      }
    });

    test('every bundled sound is marked as bundled', () {
      for (final sound in BundledSounds.catalogue()) {
        expect(sound.source, AlarmSoundSource.bundled);
      }
    });

    test('the fallback, and so the default, is Endless climb', () {
      expect(BundledSounds.fallbackId, 'loop_ascend');
      expect(BundledSounds.isBundled(BundledSounds.fallbackId), isTrue);
      expect(
        BundledSounds.removedIds,
        isNot(contains(BundledSounds.fallbackId)),
      );
      expect(BundledSounds.isBundled('emergency_sos_horn'), isTrue);
      expect(BundledSounds.isBundled('user_123'), isFalse);
    });

    test('names can be translated without touching the catalogue', () {
      final translated = BundledSounds.catalogue(
        nameOf: (id) => 'NAME:$id',
      );
      expect(translated.first.name, 'NAME:loop_ascend');
    });
  });
}
