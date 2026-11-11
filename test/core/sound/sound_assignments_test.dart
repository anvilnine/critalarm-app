import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoundAssignments', () {
    test('a topic with no choice of its own uses the default', () {
      const assignments = SoundAssignments(
        defaultSoundId: 'submarine_dive_horn',
      );
      expect(assignments.soundIdFor('prod-db'), 'submarine_dive_horn');
    });

    test('a topic with its own choice keeps it', () {
      const assignments = SoundAssignments(
        defaultSoundId: 'submarine_dive_horn',
        perTopic: {'prod-db': 'user_1'},
      );
      expect(assignments.soundIdFor('prod-db'), 'user_1');
      expect(assignments.soundIdFor('nas-backup'), 'submarine_dive_horn');
    });

    test('clearing a topic puts it back on the default', () {
      const assignments = SoundAssignments(
        defaultSoundId: 'submarine_dive_horn',
        perTopic: {'prod-db': 'user_1'},
      );
      expect(
        assignments.withTopicSound('prod-db', null).soundIdFor('prod-db'),
        'submarine_dive_horn',
      );
    });
  });

  group('the fallback rule when a sound is deleted', () {
    test('a topic using the deleted sound falls back to the default', () {
      const before = SoundAssignments(
        defaultSoundId: 'submarine_dive_horn',
        perTopic: {'prod-db': 'user_1', 'nas-backup': 'plain_loud_beep'},
      );

      final after = before.withSoundDeleted(
        'user_1',
        fallbackSoundId: BundledSounds.fallbackId,
      );

      expect(after.soundIdFor('prod-db'), 'submarine_dive_horn');
      expect(
        after.soundIdFor('nas-backup'),
        'plain_loud_beep',
        reason: 'a topic on a different sound is left alone',
      );
      expect(after.defaultSoundId, 'submarine_dive_horn');
    });

    test('deleting the default moves the default to the bundled fallback', () {
      const before = SoundAssignments(
        defaultSoundId: 'user_1',
        perTopic: {'prod-db': 'user_1'},
      );

      final after = before.withSoundDeleted(
        'user_1',
        fallbackSoundId: BundledSounds.fallbackId,
      );

      expect(after.defaultSoundId, BundledSounds.fallbackId);
      expect(
        after.soundIdFor('prod-db'),
        BundledSounds.fallbackId,
        reason: 'the topic falls back to the default, which itself moved',
      );
    });

    test('deleting a sound nothing uses changes nothing', () {
      const before = SoundAssignments(
        defaultSoundId: 'submarine_dive_horn',
        perTopic: {'prod-db': 'plain_loud_beep'},
      );

      expect(
        before.withSoundDeleted(
          'user_9',
          fallbackSoundId: BundledSounds.fallbackId,
        ),
        equals(before),
      );
    });

    test('nothing is left pointing at the deleted id', () {
      const before = SoundAssignments(
        defaultSoundId: 'user_1',
        perTopic: {'a': 'user_1', 'b': 'user_1', 'c': 'submarine_dive_horn'},
      );

      final after = before.withSoundDeleted(
        'user_1',
        fallbackSoundId: BundledSounds.fallbackId,
      );

      expect(after.defaultSoundId, isNot('user_1'));
      expect(after.perTopic.values, isNot(contains('user_1')));
      expect(after.soundIdFor('c'), 'submarine_dive_horn');
    });
  });

  group('withRemovedSoundsReplaced', () {
    test('moves the default and each topic on a removed sound', () {
      const saved = SoundAssignments(
        defaultSoundId: 'pager_beep',
        perTopic: {
          'prod': 'pulsing_klaxon',
          'db': 'classic_siren',
          'web': 'emergency_tone_ladder',
        },
      );
      final after = saved.withRemovedSoundsReplaced(
        BundledSounds.removedIds,
        replacementId: BundledSounds.fallbackId,
      );
      expect(after.defaultSoundId, 'loop_ascend');
      expect(after.perTopic, {
        'prod': 'loop_ascend',
        'db': 'classic_siren',
        'web': 'loop_ascend',
      });
    });

    test('leaves choices that still ship as they are', () {
      const saved = SoundAssignments(
        defaultSoundId: 'user_1',
        perTopic: {'prod': 'pack_library_boxing_bell'},
      );
      expect(
        saved.withRemovedSoundsReplaced(
          BundledSounds.removedIds,
          replacementId: BundledSounds.fallbackId,
        ),
        saved,
      );
    });
  });
}
